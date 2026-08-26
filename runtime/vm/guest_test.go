package vm

import (
	"bytes"
	"os"
	"testing"
)





func TestVMGuestDispatch(t *testing.T) {
	cases := [][]string{
		{"age-key"},
		{"ephemeral-ssh", "--mountpoint-bin", "/bin/true"},
		{"home-manager-upgrade"},
	}
	for _, args := range cases {
		rc := Run(args)
		if rc == exitOK {
			t.Errorf("expected non-OK dispatch for guest command %v", args)
		}
	}
}

func TestVMUnknownCommand(t *testing.T) {
	
	r, w, _ := os.Pipe()
	old := os.Stderr
	os.Stderr = w
	rc := Run([]string{"definitely-not-a-command"})
	w.Close()
	os.Stderr = old
	buf := make([]byte, 1024)
	n, _ := r.Read(buf)
	if rc != exitUsage {
		t.Fatalf("expected exitUsage, got %d", rc)
	}
	if !bytes.Contains(buf[:n], []byte("unknown vm command")) {
		t.Fatalf("expected unknown vm command message, got %q", buf[:n])
	}
}
