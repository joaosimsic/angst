package vm

import (
	"net"
	"testing"
)

func TestCheckHealthNoQemu(t *testing.T) {
	r := checkHealth(func(string) (int, string, string) { return 0, "", "" })
	if r.QemuRunning {
		t.Fatal("expected no qemu running")
	}
	if r.PortListening != nil || r.SSHReachable != nil {
		t.Fatal("expected nil port/ssh when no qemu")
	}
}

func TestPortListens(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	port := uint16(l.Addr().(*net.TCPAddr).Port)
	if !portListens(port) {
		t.Fatalf("expected port %d to be reported listening", port)
	}
}
