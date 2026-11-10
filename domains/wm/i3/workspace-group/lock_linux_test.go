package i3workspacegroup

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestAcquireDaemonLockRejectsSecondDaemon(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	first, err := acquireDaemonLock(false)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()

	if _, err := acquireDaemonLock(false); !errors.Is(err, errDaemonRunning) {
		t.Fatalf("acquireDaemonLock() error = %v, want %v", err, errDaemonRunning)
	}
}

func TestDaemonLockReplaceTakesOver(t *testing.T) {
	if os.Getenv("GO_WANT_DAEMON_LOCK_CHILD") == "1" {
		if _, err := acquireDaemonLock(false); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("locked")
		select {}
	}

	directory := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", directory)

	binary := filepath.Join(directory, "i3-workspace-group")
	data, err := os.ReadFile(os.Args[0])
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(binary, data, 0o755); err != nil {
		t.Fatal(err)
	}

	child := exec.Command(binary, "-test.run=^TestDaemonLockReplaceTakesOver$", "daemon")
	child.Env = append(os.Environ(), "GO_WANT_DAEMON_LOCK_CHILD=1")
	stdout, err := child.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() {
		if child.Process != nil {
			_ = child.Process.Kill()
		}
	}()

	line, err := bufio.NewReader(stdout).ReadString('\n')
	if err != nil {
		t.Fatalf("read child output: %v", err)
	}
	if line != "locked\n" {
		t.Fatalf("child output = %q, want locked", line)
	}

	lock, err := acquireDaemonLock(true)
	if err != nil {
		t.Fatalf("acquireDaemonLock(true): %v", err)
	}
	lock.Close()

	done := make(chan error, 1)
	go func() {
		done <- child.Wait()
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("replaced daemon did not exit")
	}
}

func TestDaemonLockHoldersFindsCurrentProcess(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	lock, err := acquireDaemonLock(false)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()

	found := false
	for _, pid := range daemonLockHolders(daemonLockPath()) {
		if pid == os.Getpid() {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("daemonLockHolders() did not find pid %d", os.Getpid())
	}
}
