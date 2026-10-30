package vm

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
)

const (
	serviceVM         = "vm"
	serviceMCP        = "vm-mcp"
	serviceSupervisor = "vm-supervisor"
	mcpPort           = 8765
)

type ServiceState struct {
	Service   string   `json:"service"`
	PID       int      `json:"pid"`
	ParentPID int      `json:"parent_pid,omitempty"`
	StartedAt string   `json:"started_at"`
	Host      string   `json:"host"`
	Port      int      `json:"port"`
	Cmd       []string `json:"cmd"`
	Log       string   `json:"log"`
	ManagedBy string   `json:"managed_by,omitempty"`
	Detached  bool     `json:"detached,omitempty"`
}

type ChildSpec struct {
	Name      string
	Program   string
	Args      []string
	Env       []string
	LogPath   string
	ManagedBy string
	ParentPID int
}

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

func processRunning(pid int) bool {
	if pid <= 0 {
		return false
	}
	if err := syscall.Kill(pid, 0); err != nil {
		return false
	}
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return true
	}
	end := bytes.LastIndexByte(b, ')')
	if end < 0 || end+2 >= len(b) {
		return true
	}
	return b[end+2] != 'Z'
}

func processAlive(pid int) bool {
	return processRunning(pid)
}

func (c *Controller) isActive(name string) bool {
	st, ok := c.read(name)
	if !ok {
		return false
	}
	return processAlive(st.PID)
}

func (c *Controller) StartChild(spec ChildSpec, stdout, stderr io.Writer) (*exec.Cmd, error) {
	if st, ok := c.read(spec.Name); ok && c.isActive(spec.Name) {
		return nil, fmt.Errorf("Service '%s' is already running (PID: %d).", spec.Name, st.PID)
	}
	if spec.LogPath == "" {
		spec.LogPath = filepath.Join(c.stateDir(), "logs", spec.Name+".log")
	}
	if err := os.MkdirAll(filepath.Dir(spec.LogPath), 0o755); err != nil {
		return nil, err
	}
	if stdout == nil {
		stdout = io.Discard
	}
	if stderr == nil {
		stderr = io.Discard
	}

	argv := append([]string{spec.Program}, spec.Args...)
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Env = append(os.Environ(), spec.Env...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid:   true,
		Pdeathsig: syscall.SIGTERM,
	}
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("Failed to spawn child process: %w", err)
	}

	state := &ServiceState{
		Service:   spec.Name,
		PID:       cmd.Process.Pid,
		ParentPID: spec.ParentPID,
		StartedAt: time.Now().UTC().Format(time.RFC3339),
		Host:      targetHost(),
		Port:      2222,
		Cmd:       argv,
		Log:       spec.LogPath,
		ManagedBy: spec.ManagedBy,
	}
	if err := c.write(spec.Name, state); err != nil {
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		_, _ = cmd.Process.Wait()
		return nil, err
	}
	return cmd, nil
}

func (c *Controller) Start(name, program string, args, env []string, headless bool) (int, error) {
	return c.StartDetached(name, program, args, env, "")
}

func (c *Controller) StartDetached(name, program string, args, env []string, managedBy string) (int, error) {
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
		ManagedBy: managedBy,
		Detached:  true,
	}
	if err := c.write(name, state); err != nil {
		return 0, err
	}
	return pid, nil
}

func (c *Controller) StartCommand(name, program string, args, env []string) (int, error) {
	return c.Start(name, program, args, env, false)
}

func (c *Controller) Stop(name string) error {
	st, ok := c.read(name)
	if !ok {
		return fmt.Errorf("No state configuration file found for service '%s'.", name)
	}
	if c.isActive(name) {
		if st.Detached {
			terminateDetached(st.PID, 5*time.Second)
		} else if proc, err := os.FindProcess(st.PID); err == nil {
			_ = proc.Signal(syscall.SIGTERM)
		}
	} else {
		fmt.Fprintf(os.Stderr, "Process with tracking PID %d was already terminated.\n", st.PID)
	}
	c.clear(name)
	return nil
}

func terminateDetached(pid int, timeout time.Duration) {
	if !processAlive(pid) {
		return
	}
	_ = syscall.Kill(pid, syscall.SIGTERM)
	deadline := time.Now().Add(timeout)
	for processAlive(pid) && time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
	}
	if processAlive(pid) {
		_ = syscall.Kill(pid, syscall.SIGKILL)
	}
	terminateProcessGroup(pid)
}

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
