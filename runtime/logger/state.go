package logger

import (
	"os"
	"path/filepath"
	"time"
)

func StateDir() string {
	if v := os.Getenv("ANGST_STATE_DIR"); v != "" {
		return v
	}
	if v := os.Getenv("XDG_STATE_HOME"); v != "" {
		return filepath.Join(v, "angst")
	}
	home := os.Getenv("HOME")
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	return filepath.Join(home, ".local", "state", "angst")
}

func EnsureStateDir() error {
	return os.MkdirAll(StateDir(), 0o755)
}

func Stamp() string {
	return time.Now().Format("2006-01-02T15-04-05")
}

func Timestamp() string {
	return time.Now().Format("15:04:05")
}

func SwitchLogPath(stamp string) string {
	return filepath.Join(StateDir(), "switch-"+stamp+".log")
}

func LatestPath() string {
	return filepath.Join(StateDir(), "latest.log")
}

func ExitPath(stamp string) string {
	return filepath.Join(StateDir(), "exit-"+stamp)
}

func User() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	return "user"
}

func Hostname() string {
	h, err := os.Hostname()
	if err != nil || h == "" {
		return "unknown"
	}
	return h
}
