//go:build linux

package i3workspacegroup

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
)

func acquireDaemonLock() (*os.File, error) {
	directory := os.Getenv("XDG_RUNTIME_DIR")
	if directory == "" {
		directory = os.TempDir()
	}
	path := filepath.Join(directory, fmt.Sprintf("i3-workspace-group-%d.lock", os.Getuid()))

	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		return nil, fmt.Errorf("another i3-workspace-group daemon is already running")
	}
	return file, nil
}
