package vm

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newMCPTestServer() *httptest.Server {
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
	return httptest.NewServer(mux)
}

func postRPC(t *testing.T, srv *httptest.Server, method string, params any, id any) map[string]any {
	t.Helper()
	body := map[string]any{"method": method}
	if params != nil {
		body["params"] = params
	}
	if id != nil {
		body["id"] = id
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/mcp", bytes.NewReader(b))
	req.Header.Set("Accept", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	json.NewDecoder(resp.Body).Decode(&out)
	return out
}

func TestMCPSmoke(t *testing.T) {
	srv := newMCPTestServer()
	defer srv.Close()

	init := postRPC(t, srv, "initialize", map[string]any{}, 1)
	if init["error"] != nil {
		t.Fatalf("initialize error: %v", init["error"])
	}
	res := init["result"].(map[string]any)
	if res["protocolVersion"] != mcpProtocolVersion {
		t.Fatalf("unexpected protocol version: %v", res["protocolVersion"])
	}
	si := res["serverInfo"].(map[string]any)
	if si["name"] != "vm-mcp" {
		t.Fatalf("unexpected server name: %v", si["name"])
	}
	if _, ok := res["capabilities"].(map[string]any)["tools"]; !ok {
		t.Fatal("missing tools capability")
	}

	list := postRPC(t, srv, "tools/list", nil, 2)
	tools := list["result"].(map[string]any)["tools"].([]any)
	if len(tools) != 3 {
		t.Fatalf("expected 3 tools, got %d", len(tools))
	}

	call := postRPC(t, srv, "tools/call", map[string]any{"name": "vm_exec", "arguments": map[string]any{"command": "echo hi"}}, 3)
	if call["error"] != nil {
		t.Fatalf("tools/call error: %v", call["error"])
	}

	unknown := postRPC(t, srv, "bogus/method", nil, 4)
	errv, ok := unknown["error"].(map[string]any)
	if !ok || int(errv["code"].(float64)) != -32601 {
		t.Fatalf("expected -32601, got %v", unknown["error"])
	}
}

func TestMCPStreamEndpoint(t *testing.T) {
	srv := newMCPTestServer()
	defer srv.Close()
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/mcp", nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if ct := resp.Header.Get("Content-Type"); ct != "text/event-stream" {
		t.Fatalf("expected text/event-stream, got %q", ct)
	}
	b, _ := io.ReadAll(resp.Body)
	if !bytes.Contains(b, []byte(": vm-mcp stream ready")) {
		t.Fatalf("unexpected stream body: %q", b)
	}
}

func TestMCPHealth(t *testing.T) {
	srv := newMCPTestServer()
	defer srv.Close()
	resp, err := http.Get(srv.URL + "/health")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	json.NewDecoder(resp.Body).Decode(&out)
	if out["status"] != "ok" {
		t.Fatalf("unexpected status: %v", out["status"])
	}
}
