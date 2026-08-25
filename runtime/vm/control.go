package vm

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
)

const (
	serviceVM  = "vm"
	serviceMCP = "vm-mcp"
	mcpPort    = 8765
)

// ServiceState is the on-disk JSON state for a managed background service
// (mirrors the schema defined in rm-tools.md).
type ServiceState struct {
	Service   string   `json:"service"`
	PID       int      `json:"pid"`
	StartedAt string   `json:"started_at"`
	Host      string   `json:"host"`
	Port      int      `json:"port"`
	Cmd       []string `json:"cmd"`
	Log       string   `json:"log"`
}

// Controller manages JSON state files and background process lifecycle under
// VM_STATE_DIR. It is the Go port of the Rust `VmProcessController`.
type Controller struct {
	StateDir string
}

var controller = &Controller{}

func defaultStateDir() string {
	if d := os.Getenv("VM_STATE_DIR"); d != "" {
		return d
	}
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		if home == "" {
			home = "/tmp"
		}
		base = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(base, "angst", "vm")
}

func (c *Controller) stateDir() string {
	if c.StateDir != "" {
		return c.StateDir
	}
	return defaultStateDir()
}

func (c *Controller) stateFile(name string) string {
	return filepath.Join(c.stateDir(), name+".json")
}

func (c *Controller) read(name string) (*ServiceState, bool) {
	b, err := os.ReadFile(c.stateFile(name))
	if err != nil {
		return nil, false
	}
	var st ServiceState
	if err := json.Unmarshal(b, &st); err != nil {
		return nil, false
	}
	return &st, true
}

func (c *Controller) write(name string, st *ServiceState) error {
	if err := os.MkdirAll(c.stateDir(), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(c.stateFile(name), b, 0o644)
}

func (c *Controller) clear(name string) {
	_ = os.Remove(c.stateFile(name))
}

// isActive reports whether the tracked PID is a live process.
func (c *Controller) isActive(name string) bool {
	st, ok := c.read(name)
	if !ok {
		return false
	}
	proc, err := os.FindProcess(st.PID)
	if err != nil {
		return false
	}
	return proc.Signal(syscall.Signal(0)) == nil
}

// Start spawns `program args` detached in the background, redirecting output
// to logs/<name>.log, and records JSON state.
func (c *Controller) Start(name, program string, args, env []string, headless bool) (int, error) {
	logDir := filepath.Join(c.stateDir(), "logs")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		return 0, err
	}
	logPath := filepath.Join(logDir, name+".log")

	if st, ok := c.read(name); ok && c.isActive(name) {
		return st.PID, fmt.Errorf("Service '%s' is already running (PID: %d).", name, st.PID)
	}

	logFile, err := os.Create(logPath)
	if err != nil {
		return 0, err
	}
	defer logFile.Close()

	argv := append([]string{program}, args...)
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Env = append(os.Environ(), env...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	if err := cmd.Start(); err != nil {
		return 0, fmt.Errorf("Failed to spawn background process: %w", err)
	}
	pid := cmd.Process.Pid

	state := &ServiceState{
		Service:   name,
		PID:       pid,
		StartedAt: time.Now().UTC().Format(time.RFC3339),
		Host:      targetHost(),
		Port:      2222,
		Cmd:       argv,
		Log:       logPath,
	}
	if err := c.write(name, state); err != nil {
		return 0, err
	}
	return pid, nil
}

// StartCommand is a convenience wrapper for launching an arbitrary command.
func (c *Controller) StartCommand(name, program string, args, env []string) (int, error) {
	return c.Start(name, program, args, env, false)
}

// Stop terminates the tracked process (SIGTERM) and clears its state.
func (c *Controller) Stop(name string) error {
	st, ok := c.read(name)
	if !ok {
		return fmt.Errorf("No state configuration file found for service '%s'.", name)
	}
	if c.isActive(name) {
		if proc, err := os.FindProcess(st.PID); err == nil {
			_ = proc.Signal(syscall.SIGTERM)
		}
	} else {
		fmt.Fprintf(os.Stderr, "Process with tracking PID %d was already terminated.\n", st.PID)
	}
	c.clear(name)
	return nil
}

// Logs tails the service's log file (streaming).
func (c *Controller) Logs(name string, lines uint32) error {
	logPath := filepath.Join(c.stateDir(), "logs", name+".log")
	if _, err := os.Stat(logPath); err != nil {
		return fmt.Errorf("No log file found for service '%s'.", name)
	}
	cmd := exec.Command("tail", "-n", fmt.Sprintf("%d", lines), "-f", logPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
