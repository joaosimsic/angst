package vm

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
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
			Headless *bool `json:"headless"`
			FullHd   bool  `json:"fullHd"`
		}
		if err := json.Unmarshal(args, &ha); err == nil && ha.Headless != nil {
			headless = *ha.Headless
		}
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Result: mustJSON(runVmRestart(headless, ha.FullHd))}
	default:
		return &mcpResponse{JSONRPC: "2.0", ID: req.ID, Error: &mcpError{Code: -32602, Message: fmt.Sprintf("Tool '%s' not found", params.Name)}}
	}
}

type managedMCP struct {
	cmd     *exec.Cmd
	done    chan error
	logFile *os.File
	owned   bool
}

func (m *managedMCP) stop(timeout time.Duration) {
	if m == nil || !m.owned {
		return
	}
	if m.cmd != nil {
		terminateCmd(m.cmd, m.done, timeout)
		m.cmd = nil
		m.done = nil
		controller.clear(serviceMCP)
	}
	if m.logFile != nil {
		_ = m.logFile.Close()
		m.logFile = nil
	}
}

func mcpServerArgs() []string {
	return []string{"mcp", "run-server", "--port", strconv.Itoa(mcpPort)}
}

func mcpListening() bool {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", mcpPort), 200*time.Millisecond)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

func mcpHealth(path string) bool {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%d%s", mcpPort, path))
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false
	}
	var payload struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return false
	}
	return payload.Status == "ok"
}

func mcpReachable() bool {
	return mcpHealth("/healthz") || mcpHealth("/health")
}

func waitForMCP(want bool, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for {
		if want {
			if mcpReachable() {
				return true
			}
		} else if !mcpListening() {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(100 * time.Millisecond)
	}
}

func managerActive(managedBy string) bool {
	switch managedBy {
	case serviceSupervisor:
		return controller.isActive(serviceSupervisor)
	case serviceVM:
		return controller.isActive(serviceVM)
	default:
		return true
	}
}

func mcpManagedBySupervisor() bool {
	st, ok := controller.read(serviceMCP)
	return ok && st.ManagedBy == serviceSupervisor && controller.isActive(serviceSupervisor)
}

func ensureMCPServer(foreground bool, parentPID int) (*managedMCP, error) {
	st, hasState := controller.read(serviceMCP)
	if mcpListening() {
		if !mcpReachable() {
			return nil, fmt.Errorf("port %d is already in use by a non-MCP process", mcpPort)
		}
		if hasState && st.ManagedBy != "" && !managerActive(st.ManagedBy) {
			_ = controller.Stop(serviceMCP)
			_ = waitForMCP(false, 2*time.Second)
			controller.clear(serviceMCP)
		} else {
			return &managedMCP{owned: false}, nil
		}
	}

	if controller.isActive(serviceMCP) {
		_ = controller.Stop(serviceMCP)
		_ = waitForMCP(false, 2*time.Second)
		controller.clear(serviceMCP)
	}

	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	args := mcpServerArgs()

	if foreground {
		logPath := filepath.Join(controller.stateDir(), "logs", serviceMCP+".log")
		if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
			return nil, err
		}
		logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
		if err != nil {
			return nil, err
		}
		cmd, err := controller.StartChild(ChildSpec{
			Name:      serviceMCP,
			Program:   exe,
			Args:      args,
			Env:       []string{fmt.Sprintf("VM_SUPERVISOR_PID=%d", parentPID)},
			LogPath:   logPath,
			ManagedBy: serviceSupervisor,
			ParentPID: parentPID,
		}, logFile, logFile)
		if err != nil {
			_ = logFile.Close()
			return nil, err
		}
		mcp := &managedMCP{cmd: cmd, done: make(chan error, 1), logFile: logFile, owned: true}
		go func() {
			mcp.done <- cmd.Wait()
		}()
		if !waitForMCP(true, 5*time.Second) {
			mcp.stop(2 * time.Second)
			return nil, fmt.Errorf("MCP server did not start listening on port %d", mcpPort)
		}
		return mcp, nil
	}

	if _, err := controller.StartDetached(serviceMCP, exe, args, nil, serviceVM); err != nil {
		return nil, err
	}
	if !waitForMCP(true, 5*time.Second) {
		_ = controller.Stop(serviceMCP)
		return nil, fmt.Errorf("MCP server did not start listening on port %d", mcpPort)
	}
	return &managedMCP{owned: true}, nil
}

func supervisorPID() int {
	if v := os.Getenv("VM_SUPERVISOR_PID"); v != "" {
		if pid, err := strconv.Atoi(v); err == nil && processAlive(pid) {
			return pid
		}
	}
	if st, ok := controller.read(serviceSupervisor); ok && processAlive(st.PID) {
		return st.PID
	}
	return 0
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
		return toolContent("VM is stopped", false)
	}
	code, _, _ := sshExec("echo ok")
	if code == 0 {
		return toolContent("VM is running and accepting SSH connections", false)
	}
	return toolContent("VM process is active but SSH is unreachable", false)
}

func runVmRestart(headless bool, fullHd bool) map[string]any {
	if pid := supervisorPID(); pid > 0 {
		if err := writeRestartRequest(restartRequest{Headless: headless, FullHD: fullHd}); err != nil {
			return toolContent(fmt.Sprintf("VM restart failed: %v", err), true)
		}
		if err := syscall.Kill(pid, syscall.SIGUSR1); err != nil {
			return toolContent(fmt.Sprintf("VM restart failed: %v", err), true)
		}
		return toolContent("VM restart requested", false)
	}

	_ = controller.Stop(serviceVM)
	args := []string{"--detach"}
	if headless {
		args = append(args, "--headless")
	} else {
		args = append(args, "--gtk")
	}
	if fullHd {
		args = append(args, "--full-hd")
	}
	rc := startVM(args, false)
	if rc != exitOK {
		return toolContent("VM restart failed", true)
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
				"description": "Restart the VM",
				"inputSchema": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"headless": map[string]any{"type": "boolean", "description": "Whether to start the VM without a graphical display window."},
						"fullHd":   map[string]any{"type": "boolean", "description": "Use 1920x1080 instead of the default 1280x720 display resolution."},
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

func handleLive(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok"})
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
	mux.HandleFunc("/healthz", handleLive)
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
		if mcpListening() {
			if mcpReachable() {
				fmt.Println("VM MCP Server is already running.")
				return exitOK
			}
			fmt.Fprintf(os.Stderr, "port %d is already in use by a non-MCP process\n", mcpPort)
			return exitError
		}
		exe, err := os.Executable()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		pid, err := controller.StartDetached(serviceMCP, exe, mcpServerArgs(), nil, "")
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		if !waitForMCP(true, 5*time.Second) {
			_ = controller.Stop(serviceMCP)
			fmt.Fprintln(os.Stderr, "MCP server did not start listening")
			return exitError
		}
		fmt.Printf("VM MCP Server starting (PID %d)\n", pid)
		return exitOK
	case "stop":
		if mcpManagedBySupervisor() {
			fmt.Fprintln(os.Stderr, "MCP server is managed by 'vm start'. Use 'vm stop'.")
			return exitError
		}
		if err := controller.Stop(serviceMCP); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return exitError
		}
		fmt.Println("VM MCP Server stopped.")
		return exitOK
	case "restart":
		if mcpManagedBySupervisor() {
			fmt.Fprintln(os.Stderr, "MCP server is managed by 'vm start'. Use 'vm restart'.")
			return exitError
		}
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
		var health struct {
			VmReachable bool `json:"VmReachable"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&health)
		if health.VmReachable {
			fmt.Println("healthy (process active, /health ok, VM reachable)")
		} else {
			fmt.Println("degraded (process active, /health ok, VM unreachable)")
		}
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
