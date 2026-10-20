package vm

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

type supervisorOptions struct {
	Host       string
	Runner     string
	Repo       string
	SharedDir  string
	DiskImage  string
	Headless   bool
	FullHD     bool
	LogPath    string
	Foreground bool
}

type vmProcess struct {
	cmd  *exec.Cmd
	done chan error
}

type restartRequest struct {
	Headless bool `json:"headless"`
	FullHD   bool `json:"full_hd"`
}

func startVMProcess(opts supervisorOptions, stdout, stderr io.Writer) (*vmProcess, error) {
	cmd, err := controller.StartChild(ChildSpec{
		Name:      serviceVM,
		Program:   opts.Runner,
		Env:       buildVMEnv(opts.Host, opts.Repo, opts.SharedDir, opts.DiskImage, opts.Headless, opts.FullHD),
		LogPath:   opts.LogPath,
		ManagedBy: serviceSupervisor,
		ParentPID: os.Getpid(),
	}, stdout, stderr)
	if err != nil {
		return nil, err
	}
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()
	return &vmProcess{cmd: cmd, done: done}, nil
}

func (v *vmProcess) stop(timeout time.Duration) {
	if v == nil || v.cmd == nil {
		return
	}
	terminateCmd(v.cmd, v.done, timeout)
	v.cmd = nil
	v.done = nil
}

func terminateProcessGroup(pid int) {
	if pid <= 0 {
		return
	}
	if err := syscall.Kill(-pid, syscall.SIGTERM); err != nil {
		return
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if err := syscall.Kill(-pid, 0); err != nil {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	_ = syscall.Kill(-pid, syscall.SIGKILL)
}

func waitDone(done <-chan error, timeout time.Duration) {
	if done == nil {
		return
	}
	select {
	case <-done:
	case <-time.After(timeout):
	}
}

func terminateCmd(cmd *exec.Cmd, done <-chan error, timeout time.Duration) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	pid := cmd.Process.Pid
	_ = cmd.Process.Signal(syscall.SIGTERM)

	deadline := time.Now().Add(timeout)
	for processRunning(pid) && time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
	}
	if processRunning(pid) {
		_ = cmd.Process.Kill()
	}

	terminateProcessGroup(pid)
	waitDone(done, 5*time.Second)
}

func restartRequestPath() string {
	return filepath.Join(controller.stateDir(), "restart.json")
}

func writeRestartRequest(req restartRequest) error {
	if err := os.MkdirAll(controller.stateDir(), 0o755); err != nil {
		return err
	}
	b, err := json.Marshal(req)
	if err != nil {
		return err
	}
	path := restartRequestPath()
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func readRestartRequest() (restartRequest, bool) {
	var req restartRequest
	b, err := os.ReadFile(restartRequestPath())
	if err != nil {
		return req, false
	}
	if err := json.Unmarshal(b, &req); err != nil {
		return req, false
	}
	_ = os.Remove(restartRequestPath())
	return req, true
}

func watchParent(parent int, gone chan<- struct{}) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for range ticker.C {
		if os.Getppid() != parent {
			select {
			case gone <- struct{}{}:
			default:
			}
			return
		}
	}
}

func restartSupervisedVM(vm *vmProcess, opts *supervisorOptions, stdout, stderr io.Writer) (*vmProcess, error) {
	req, ok := readRestartRequest()
	if !ok {
		req = restartRequest{Headless: opts.Headless, FullHD: opts.FullHD}
	}
	if !req.Headless && !detectDisplay() {
		fmt.Fprintln(os.Stderr, "warn: --gtk requested but no DISPLAY/WAYLAND_DISPLAY; falling back to headless")
		req.Headless = true
	}

	fmt.Println("Restarting VM...")
	if vm != nil {
		vm.stop(10 * time.Second)
	}
	controller.clear(serviceVM)

	opts.Headless = req.Headless
	opts.FullHD = req.FullHD
	next, err := startVMProcess(*opts, stdout, stderr)
	if err != nil {
		return nil, err
	}
	return next, nil
}

func runSupervisor(opts supervisorOptions) int {
	if err := os.MkdirAll(filepath.Dir(opts.LogPath), 0o755); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	logFile, err := os.OpenFile(opts.LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	defer logFile.Close()

	sigs := make(chan os.Signal, 8)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP, syscall.SIGUSR1)
	defer signal.Stop(sigs)

	vmOut := io.Writer(logFile)
	vmErr := io.Writer(logFile)
	if opts.Foreground {
		vmOut = io.MultiWriter(os.Stdout, logFile)
		vmErr = io.MultiWriter(os.Stderr, logFile)
	}

	state := &ServiceState{
		Service:   serviceSupervisor,
		PID:       os.Getpid(),
		ParentPID: os.Getppid(),
		StartedAt: time.Now().UTC().Format(time.RFC3339),
		Host:      opts.Host,
		Port:      2222,
		Cmd:       []string{opts.Runner},
		Log:       opts.LogPath,
		Detached:  !opts.Foreground,
	}
	if err := controller.write(serviceSupervisor, state); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	defer controller.clear(serviceSupervisor)

	mcp, err := ensureMCPServer(opts.Foreground, os.Getpid())
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	if mcp.owned {
		defer mcp.stop(5 * time.Second)
	}

	vm, err := startVMProcess(opts, vmOut, vmErr)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		controller.clear(serviceVM)
		return exitError
	}
	defer func() {
		if vm != nil {
			vm.stop(10 * time.Second)
			controller.clear(serviceVM)
		}
	}()

	parentGone := make(chan struct{}, 1)
	if opts.Foreground {
		go watchParent(os.Getppid(), parentGone)
	}

	ready := false
	deadline := time.Now().Add(300 * time.Second)
	started := time.Now()
	lastReport := 0
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	checkSSH := func() {
		code, _, _ := sshExec("true")
		if code == 0 {
			fmt.Println("VM was initialized and ready via SSH")
			ready = true
		}
	}
	checkSSH()

	for {
		select {
		case <-parentGone:
			fmt.Println("Parent exited; stopping VM.")
			return exitOK
		case sig := <-sigs:
			if sig == syscall.SIGUSR1 {
				next, restartErr := restartSupervisedVM(vm, &opts, vmOut, vmErr)
				if restartErr != nil {
					vm = nil
					fmt.Fprintln(os.Stderr, restartErr)
					continue
				}
				vm = next
				ready = false
				started = time.Now()
				lastReport = 0
				deadline = started.Add(300 * time.Second)
				ticker.Reset(2 * time.Second)
				continue
			}
			fmt.Println("Stopping VM...")
			return exitOK
		case err := <-vmDone(vm):
			vm = nil
			controller.clear(serviceVM)
			if err != nil {
				fmt.Fprintf(os.Stderr, "VM exited: %v\n", err)
				return exitError
			}
			return exitOK
		case <-ticker.C:
			if ready {
				continue
			}
			checkSSH()
			if ready {
				continue
			}
			if time.Now().After(deadline) {
				if anyQemuRunning() {
					fmt.Fprintln(os.Stderr, "\n  QEMU is running but SSH port 2222 is not accepting connections. Check 'vm logs' for boot errors.")
				} else {
					fmt.Fprintln(os.Stderr, "\n  No QEMU process found. Run 'vm logs' for details.")
				}
				return exitError
			}
			if elapsed := int(time.Since(started).Seconds()); elapsed >= lastReport+60 {
				lastReport = elapsed
				fmt.Printf("still waiting for guest SSH (elapsed %ds)\n", elapsed)
			}
		}
	}
}

func vmDone(v *vmProcess) <-chan error {
	if v == nil || v.done == nil {
		return nil
	}
	return v.done
}
