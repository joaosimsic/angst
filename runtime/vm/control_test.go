package vm

import (
	"os/exec"
	"testing"
)

func withStateDir(t *testing.T) func() {
	t.Helper()
	dir := t.TempDir()
	old := controller.StateDir
	controller.StateDir = dir
	return func() { controller.StateDir = old }
}

func TestStateReadWrite(t *testing.T) {
	restore := withStateDir(t)
	defer restore()
	st := &ServiceState{Service: "vm", PID: 42, StartedAt: "now", Host: "vm", Port: 2222, Cmd: []string{"/bin/true"}, Log: "/tmp/x.log"}
	if err := controller.write("vm", st); err != nil {
		t.Fatal(err)
	}
	got, ok := controller.read("vm")
	if !ok || got.PID != 42 {
		t.Fatalf("read mismatch: %v %v", got, ok)
	}
	controller.clear("vm")
	if _, ok := controller.read("vm"); ok {
		t.Fatal("expected cleared state")
	}
}

func TestIsActiveStalePID(t *testing.T) {
	restore := withStateDir(t)
	defer restore()
	controller.write("vm", &ServiceState{Service: "vm", PID: 999999, Log: "/tmp/x.log"})
	if controller.isActive("vm") {
		t.Fatal("expected stale pid to be inactive")
	}
}

func TestStartStopLifecycle(t *testing.T) {
	if _, err := exec.LookPath("sleep"); err != nil {
		t.Skip("sleep not available in this environment")
	}
	restore := withStateDir(t)
	defer restore()
	pid, err := controller.Start("vm", "sleep", []string{"30"}, nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if pid <= 0 {
		t.Fatal("bad pid")
	}
	if !controller.isActive("vm") {
		t.Fatal("expected active after start")
	}
	if _, err := controller.Start("vm", "sleep", []string{"30"}, nil, false); err == nil {
		t.Fatal("expected already-running error")
	}
	if err := controller.Stop("vm"); err != nil {
		t.Fatal(err)
	}
	if controller.isActive("vm") {
		t.Fatal("expected inactive after stop")
	}
}
