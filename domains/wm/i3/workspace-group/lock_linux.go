//go:build linux

package i3workspacegroup

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var errDaemonRunning = errors.New("another i3-workspace-group daemon is already running")

func daemonLockPath() string {
	directory := os.Getenv("XDG_RUNTIME_DIR")
	if directory == "" {
		directory = os.TempDir()
	}
	return filepath.Join(directory, fmt.Sprintf("i3-workspace-group-%d.lock", os.Getuid()))
}

func acquireDaemonLock(replace bool) (*os.File, error) {
	path := daemonLockPath()
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}

	deadline := time.Now().Add(5 * time.Second)
	terminated := false
	for {
		if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err == nil {
			_ = file.Truncate(0)
			_, _ = file.WriteAt([]byte(strconv.Itoa(os.Getpid())+"\n"), 0)
			return file, nil
		}

		if !replace {
			file.Close()
			return nil, errDaemonRunning
		}

		if !terminated {
			for _, pid := range daemonLockHolders(path) {
				if pid == os.Getpid() {
					continue
				}
				terminateDaemon(pid)
			}
			terminated = true
		}

		if time.Now().After(deadline) {
			file.Close()
			return nil, errDaemonRunning
		}
		time.Sleep(100 * time.Millisecond)
	}
}

func daemonLockHolders(path string) []int {
	if data, err := os.ReadFile(path); err == nil {
		if pid, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil && pid > 0 && daemonProcess(pid) {
			return []int{pid}
		}
	}

	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}

	holders := make([]int, 0)
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err != nil {
			continue
		}
		fdDirectory := filepath.Join("/proc", entry.Name(), "fd")
		fds, err := os.ReadDir(fdDirectory)
		if err != nil {
			continue
		}
		for _, fd := range fds {
			target, err := os.Readlink(filepath.Join(fdDirectory, fd.Name()))
			if err != nil || target != path {
				continue
			}
			holders = append(holders, pid)
			break
		}
	}
	return holders
}

func terminateDaemon(pid int) {
	if !daemonProcess(pid) {
		return
	}
	_ = syscall.Kill(pid, syscall.SIGTERM)
}

func daemonProcess(pid int) bool {
	executable, err := os.Readlink(filepath.Join("/proc", strconv.Itoa(pid), "exe"))
	if err != nil || filepath.Base(executable) != "i3-workspace-group" {
		return false
	}

	commandLine, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return false
	}
	for _, argument := range strings.Split(string(commandLine), "\x00") {
		if argument == "daemon" {
			return true
		}
	}
	return false
}
