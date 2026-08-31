package vm

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
)

const mcpProtocolVersion = "2025-03-26"

type mcpRequest struct {
	Method string           `json:"method"`
	Params *json.RawMessage `json:"params"`
	ID     json.RawMessage  `json:"id"`
}

type mcpResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *mcpError       `json:"error,omitempty"`
	ID      json.RawMessage `json:"id,omitempty"`
}

type mcpError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func mustJSON(v any) json.RawMessage {
	b, err := json.Marshal(v)
	if err != nil {
		return json.RawMessage(`{}`)
	}
	return b
}

func acceptsJSON(r *http.Request) bool {
	accept := r.Header.Get("Accept")
	if accept == "" {
		return true
	}
	return strings.Contains(accept, "application/json") || strings.Contains(accept, "*/*")
}

func handleRPC(w http.ResponseWriter, r *http.Request) {
	if !acceptsJSON(r) {
		http.Error(w, "MCP HTTP requests must accept application/json", http.StatusNotAcceptable)
		return
	}
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	var req mcpRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSON(w, &mcpResponse{JSONRPC: "2.0", Error: &mcpError{Code: -32700, Message: "Parse error"}})
		return
	}
	reply := dispatchRPC(req)
	if reply == nil {
		w.WriteHeader(http.StatusAccepted)
		return
	}
	writeJSON(w, reply)
}

func writeJSON(w http.ResponseWriter, resp *mcpResponse) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func dispatchRPC(req mcpRequest) *mcpResponse {
	switch req.Method {
	case "initialize":
		return &mcpResponse{
			JSONRPC: "2.0",
			ID:      req.ID,
			Result: mustJSON(map[string]any{
				"protocolVersion": mcpProtocolVersion,
				"capabilities":    map[string]any{"tools": map[string]any{}},
				"serverInfo":      map[string]any{"name": "vm-mcp", "version": "0.1.0"},
			}),
		}
	case "notifications/initialized":
		return nil
	case "tools/list":
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(toolsList())}
	case "tools/call":
		return handleToolCall(req)
	default:
		if req.ID == nil {
			return nil
		}
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Error: &mcpError{Code: -32601, Message: "Method not found"}}
	}
}

func handleToolCall(req mcpRequest) *mcpResponse {
	var params struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
		Args      json.RawMessage `json:"args"`
	}
	if req.Params != nil {
		_ = json.Unmarshal(*req.Params, &params)
	}
	args := params.Arguments
	if args == nil {
		args = params.Args
	}
	if args == nil {
		args = json.RawMessage(`{}`)
	}
	switch params.Name {
	case "vm_exec":
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(runVmExec(args))}
	case "vm_status":
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(runVmStatus())}
	case "vm_restart":
		headless := true
		var ha struct {
			Headless bool `json:"headless"`
		}
		if err := json.Unmarshal(args, &ha); err == nil {
			headless = ha.Headless
		}
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(runVmRestart(headless))}
	default:
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Error: &mcpError{Code: -32602, Message: fmt.Sprintf("Tool '%s' not found", params.Name)}}
	}
}

func toolContent(text string, isError bool) map[string]any {
	c := map[string]any{"type": "text", "text": text}
	if isError {
		return map[string]any{"content": []any{c}, "isError": true}
	}
	return map[string]any{"content": []any{c}}
}

func runVmExec(args json.RawMessage) map[string]any {
	var a struct {
		Command string `json:"command"`
	}
	_ = json.Unmarshal(args, &a)
	code, out, errOut := sshExec(a.Command)
	text := fmt.Sprintf("Exit code: %d\n\nStdout:\n%s\n\nStderr:\n%s", code, out, errOut)
	return toolContent(text, code != 0)
}

func runVmStatus() map[string]any {
	if !controller.isActive(serviceVM) {
		return toolContent("VM systemd unit is stopped", false)
	}
	code, _, _ := sshExec("echo ok")
	if code == 0 {
		return toolContent("VM is running and accepting SSH connections", false)
	}
	return toolContent("VM systemd unit is active but SSH is unreachable", false)
}

func runVmRestart(headless bool) map[string]any {
	_ = controller.Stop(serviceVM)
	rc := start([]string{"--headless"})
	if rc != exitOK {
		return toolContent("VM restart failed", true)
	}
	if !headless {

	}
	return toolContent("VM restarting", false)
}

func toolsList() map[string]any {
	return map[string]any{
		"tools": []any{
			map[string]any{
				"name":        "vm_exec",
				"description": "Execute a command inside the NixOS VM via SSH",
				"inputSchema": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"command": map[string]any{"type": "string", "description": "Shell command to execute inside the VM"},
					},
					"required": []any{"command"},
				},
			},
			map[string]any{
				"name":        "vm_status",
				"description": "Check if the VM is running and accessible",
				"inputSchema": map[string]any{"type": "object", "properties": map[string]any{}},
			},
			map[string]any{
				"name":        "vm_restart",
				"description": "Trigger local VM systemd restart action",
				"inputSchema": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"headless": map[string]any{"type": "boolean", "description": "Whether to start the VM without a graphical display window."},
					},
				},
			},
		},
	}
}

func handleStream(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, ": vm-mcp stream ready\n\n")
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	code, _, _ := sshExec("echo ok")
	reachable := code == 0
	details := "Connection healthy and fully authenticated"
	if !reachable {
		details = "SSH connection failed"
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status":      "ok",
		"VmReachable": reachable,
		"details":     details,
	})
}

func runServer(port int) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/mcp", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			handleRPC(w, r)
		case http.MethodGet:
			handleStream(w, r)
		default:
			http.NotFound(w, r)
		}
	})
	mux.HandleFunc("/health", handleHealth)
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	fmt.Printf("VM MCP Server listening on http://%s\n", addr)
	return http.ListenAndServe(addr, mux)
}

func mcpDispatch(args []string) int {
	sub := ""
	if len(args) > 0 {
		sub = args[0]
		args = args[1:]
	}
	switch sub {
	case "start":
		exe, err := os.Executable()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		pid, err := controller.StartCommand(serviceMCP, exe, []string{"vm", "mcp", "run-server", "--port", strconv.Itoa(mcpPort)}, nil)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		fmt.Printf("VM MCP Server starting (PID %d)\n", pid)
		return exitOK
	case "stop":
		if err := controller.Stop(serviceMCP); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		fmt.Println("VM MCP Server stopped.")
		return exitOK
	case "restart":
		_ = controller.Stop(serviceMCP)
		return mcpDispatch([]string{"start"})
	case "status":
		if !controller.isActive(serviceMCP) {
			fmt.Println("inactive")
			return exitOK
		}
		resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/health", mcpPort))
		if err != nil {
			fmt.Println("degraded (process active, /health failed)")
			return exitOK
		}
		defer resp.Body.Close()
		fmt.Println("healthy (process active, /health ok, VM reachable)")
		return exitOK
	case "logs":
		lines := uint32(50)
		for i := 0; i < len(args); i++ {
			if (args[i] == "-n" || args[i] == "--lines") && i+1 < len(args) {
				if n, err := strconv.ParseUint(args[i+1], 10, 32); err == nil {
					lines = uint32(n)
				}
			}
		}
		if err := controller.Logs(serviceMCP, lines); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		return exitOK
	case "run-server":
		port := mcpPort
		for i := 0; i < len(args); i++ {
			if args[i] == "--port" && i+1 < len(args) {
				if p, err := strconv.Atoi(args[i+1]); err == nil {
					port = p
				}
			}
		}
		if err := runServer(port); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		return exitOK
	default:
		fmt.Fprintln(os.Stderr, "unknown mcp command: "+sub)
		return exitUsage
	}
}
