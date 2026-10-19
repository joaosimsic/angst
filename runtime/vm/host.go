package vm

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"vm/internal/paths"
)

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func resolveUsername() string {
	if v := os.Getenv("VM_SSH_USER"); v != "" {
		return v
	}
	if v := os.Getenv("ANGST_USERNAME"); v != "" {
		return v
	}
	return "joao"
}

func resolveIdentity() string {
	if v := os.Getenv("VM_SSH_IDENTITY"); v != "" {
		return v
	}
	home, _ := os.UserHomeDir()
	if home == "" {
		home = os.Getenv("HOME")
	}
	return filepath.Join(home, ".ssh", "id_ed25519")
}

func targetHost() string {
	if v := os.Getenv("NIX_TARGET_HOST"); v != "" {
		return v
	}
	if v := os.Getenv("NIX_DEFAULT_TARGET_HOST"); v != "" {
		return v
	}
	if v := os.Getenv("ANGST_HOST"); v != "" {
		return v
	}
	return "vm"
}

func repoRoot() string {
	return paths.RepoRoot()
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		if home == "" {
			home = os.Getenv("HOME")
		}
		return filepath.Join(home, p[2:])
	}
	return p
}

func detectDisplay() bool {
	return os.Getenv("DISPLAY") != "" || os.Getenv("WAYLAND_DISPLAY") != ""
}

func sshExec(command string) (int, string, string) {
	port := envOr("VM_SSH_PORT", "2222")
	user := resolveUsername()
	identity := resolveIdentity()

	args := []string{
		"-F", "/dev/null",
		"-p", port,
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "LogLevel=ERROR",
		"-o", "IdentitiesOnly=yes",
		"-i", identity,
		fmt.Sprintf("%s@127.0.0.1", user),
	}
	if command != "" {
		args = append(args, command)
	}

	cmd := exec.Command("ssh", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	code := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			code = ee.ExitCode()
		} else {
			code = -1
		}
	}
	return code, stdout.String(), stderr.String()
}

func scpOpts() []string {
	port := envOr("VM_SSH_PORT", "2222")
	identity := resolveIdentity()
	return []string{
		"-P", port,
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "LogLevel=ERROR",
		"-o", "IdentitiesOnly=yes",
		"-i", identity,
	}
}

func ensureVmProfile(host string) error {
	repo := repoRoot()
	configPath := filepath.Join(repo, "hosts", host, "default.nix")
	if _, err := os.Stat(configPath); err != nil {
		return fmt.Errorf("Host '%s' not found.\nExpected config at: %s\nCreate it or set NIX_DEFAULT_TARGET_HOST to a valid host.", host, configPath)
	}
	out, err := exec.Command("nix", "eval", "--file", configPath, "--raw",
		"--apply", "x: if builtins.elem \"vm\" (x.profiles or []) then \"true\" else \"false\"").Output()
	if err != nil {
		return fmt.Errorf("Failed to check VM profile: %w", err)
	}
	if strings.TrimSpace(string(out)) != "true" {
		return fmt.Errorf("VM profile not enabled for host '%s'.\nAdd \"vm\" to the profiles list in %s.", host, configPath)
	}
	return nil
}

func findRunner(host string) string {
	repo := repoRoot()
	candidates := []string{
		filepath.Join(repo, "result", "bin", "run-"+host+"-vm"),
		filepath.Join(repo, "result", "bin", "run-nixos-vm"),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return ""
}

func buildVm(host string) error {
	repo := repoRoot()
	username := envOr("ANGST_USERNAME", resolveUsername())
	args := []string{"build", "--refresh", "--no-write-lock-file",
		fmt.Sprintf(".#nixosConfigurations.%s.config.system.build.vm", host)}
	cmd := exec.Command("nix", args...)
	cmd.Dir = repo
	cmd.Env = append(os.Environ(), "ANGST_USERNAME="+username)
	if pw := os.Getenv("ANGST_PASSWORD"); pw != "" {
		cmd.Env = append(cmd.Env, "ANGST_PASSWORD="+pw)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func killStaleQemu(disk string) {
	out, err := exec.Command("sh", "-c",
		fmt.Sprintf("pids=$(pgrep -f 'qemu-system.*\\b%s' 2>/dev/null || true); [ -n \"$pids\" ] && kill -TERM $pids 2>/dev/null; echo \"$pids\"", disk)).Output()
	if err == nil {
		s := strings.TrimSpace(string(out))
		if s != "" {
			fmt.Printf("Killed stale QEMU process(es): %s\n", s)
			controller.clear(serviceVM)
			controller.clear(serviceMCP)
			time.Sleep(2 * time.Second)
		}
	}
}

func prepareSharedDir(host string) (string, error) {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		if home == "" {
			home = os.Getenv("HOME")
		}
		base = filepath.Join(home, ".local", "state")
	}
	dir := filepath.Join(base, "vm", "keys", host)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	sources := []struct {
		src  string
		dest string
	}{
		{expandHome("~/.config/age/keys.txt"), "age-keys.txt"},
		{expandHome("~/.config/age/work-keys.txt"), "work-keys.txt"},
	}
	found := false
	for _, s := range sources {
		if _, err := os.Stat(s.src); err != nil {
			_ = os.Remove(filepath.Join(dir, s.dest))
			continue
		}
		data, err := os.ReadFile(s.src)
		if err != nil {
			return "", fmt.Errorf("Failed to read age key %s: %w", s.src, err)
		}
		dst := filepath.Join(dir, s.dest)
		if err := os.WriteFile(dst, data, 0o600); err != nil {
			return "", fmt.Errorf("Failed to write %s: %w", dst, err)
		}
		found = true
	}
	if !found {
		fmt.Fprintln(os.Stderr, "warn: No host age key found (~/.config/age/keys.txt). VM will boot without secrets.")
	}
	return dir, nil
}

func start(args []string) int {
	headless := true
	gtk := false
	for _, a := range args {
		if a == "--headless" {
			headless = true
		}
		if a == "--gtk" || a == "--display" {
			gtk = true
		}
	}
	if gtk {
		headless = false
	}
	host := targetHost()
	if err := ensureVmProfile(host); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	disk := fmt.Sprintf("%s.qcow2", host)
	killStaleQemu(disk)

	effectiveHeadless := headless && !gtk
	if !effectiveHeadless && !detectDisplay() {
		fmt.Fprintln(os.Stderr, "warn: --gtk requested but no DISPLAY/WAYLAND_DISPLAY; falling back to headless")
		effectiveHeadless = true
	}

	runner := findRunner(host)
	if runner == "" {
		fmt.Printf("VM image not found. Building NixOS VM system image for host '%s'...\n", host)
		if err := buildVm(host); err != nil {
			fmt.Fprintln(os.Stderr, "Nix compilation of the target VM profile failed.")
			return exitError
		}
		runner = findRunner(host)
		if runner == "" {
			fmt.Fprintln(os.Stderr, "VM runner still not found after build.")
			return exitError
		}
	}

	sharedDir, err := prepareSharedDir(host)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	repo := repoRoot()
	diskImg := envOr("NIX_DISK_IMAGE", fmt.Sprintf("%s/%s.qcow2", repo, host))
	qemuOpts := ""
	if effectiveHeadless {
		qemuOpts = "-display none"
	}
	env := []string{
		"SHARED_DIR=" + sharedDir,
		"ANGST_REPO=" + repo,
		"NIX_DISK_IMAGE=" + diskImg,
		"QEMU_NET_OPTS=hostfwd=tcp::2222-:22",
		"QEMU_OPTS=" + qemuOpts,
		"NIX_DEFAULT_TARGET_HOST=" + host,
	}

	if controller.isActive(serviceVM) {
		code, _, _ := sshExec("true")
		if code == 0 {
			fmt.Fprintln(os.Stderr, "VM is already running.")
			return exitError
		}
		fmt.Fprintln(os.Stderr, "VM process is running but SSH is not available. Try 'vm restart'.")
		return exitError
	}

	pid, err := controller.Start(serviceVM, runner, nil, env, effectiveHeadless)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	fmt.Printf("VM Started! (PID %d) Validating connection status...\n", pid)

	for i := 1; i <= 750; i++ {
		code, _, _ := sshExec("true")
		if code == 0 {
			fmt.Println("VM was initialized and ready via SSH")
			return exitOK
		}
		elapsed := i * 2
		if elapsed%60 == 0 {
			fmt.Printf("still waiting for guest SSH (elapsed %ds)\n", elapsed)
		}
		time.Sleep(2 * time.Second)
	}

	if anyQemuRunning() {
		fmt.Fprintln(os.Stderr, "\n  QEMU is running but SSH port 2222 is not accepting connections. Check 'vm logs' for boot errors.")
	} else {
		fmt.Fprintln(os.Stderr, "\n  No QEMU process found. Run 'vm logs' for details.")
	}
	return exitError
}

func stop(args []string) int {
	if err := controller.Stop(serviceVM); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	fmt.Println("VM stopped.")
	return exitOK
}

func restart(args []string) int {
	_ = controller.Stop(serviceVM)
	return start(args)
}

func status(args []string) int {
	if controller.isActive(serviceVM) {
		code, _, _ := sshExec("true")
		if code == 0 {
			fmt.Println("VM Status: Running")
		} else {
			fmt.Println("VM Status: Running (not accepting connections)")
		}
	} else {
		fmt.Println("VM Status: Stopped (No VM is currently running)")
	}
	return exitOK
}

func health(args []string) int {
	report := checkHealth(sshExec)
	fmt.Print(report.String())
	if report.SSHReachable != nil && *report.SSHReachable {
		return exitOK
	}
	return exitError
}

func logsCmd(args []string) int {
	lines := uint32(50)
	for i := 0; i < len(args); i++ {
		if (args[i] == "-n" || args[i] == "--lines") && i+1 < len(args) {
			if n, err := strconv.ParseUint(args[i+1], 10, 32); err == nil {
				lines = uint32(n)
			}
		}
	}
	if err := controller.Logs(serviceVM, lines); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	return exitOK
}

func sshCmd(args []string) int {
	autoStart := false
	tty := false
	var rest []string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--auto-start":
			autoStart = true
		case "-t", "--tty":
			tty = true
		default:
			rest = append(rest, args[i])
		}
	}
	host := targetHost()
	if err := ensureVmProfile(host); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return exitError
	}
	if autoStart {
		code, _, _ := sshExec("true")
		if code != 0 {
			fmt.Println("VM not running. Starting headless...")
			if rc := start([]string{"--headless"}); rc != exitOK {
				return rc
			}
		}
	}

	port := envOr("VM_SSH_PORT", "2222")
	user := resolveUsername()
	identity := resolveIdentity()
	sshArgs := []string{
		"-F", "/dev/null",
		"-p", port,
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "LogLevel=ERROR",
		"-o", "IdentitiesOnly=yes",
		"-i", identity,
	}
	if tty {
		sshArgs = append(sshArgs, "-t")
	}
	sshArgs = append(sshArgs, fmt.Sprintf("%s@127.0.0.1", user))
	sshArgs = append(sshArgs, rest...)

	cmd := exec.Command("ssh", sshArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Println("Tip: Check 'vm status' and 'vm logs' for VM health.")
		return exitError
	}
	return exitOK
}

func execCmd(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "exec requires a command")
		return exitUsage
	}
	code, out, errOut := sshExec(strings.Join(args, " "))
	fmt.Print(out)
	fmt.Fprint(os.Stderr, errOut)
	if code == 0 {
		return exitOK
	}
	return exitError
}

func copyToCmd(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "copy-to requires <src> <dest>")
		return exitUsage
	}
	return scpCopy(args[0], args[1], true)
}

func copyFromCmd(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "copy-from requires <src> <dest>")
		return exitUsage
	}
	return scpCopy(args[0], args[1], false)
}

func scpCopy(src, dest string, toRemote bool) int {
	user := resolveUsername()
	opts := scpOpts()
	remote := fmt.Sprintf("%s@127.0.0.1:%s", user, dest)
	var argv []string
	if toRemote {
		argv = append(opts, src, remote)
	} else {
		argv = append(opts, remote, src)
	}
	cmd := exec.Command("scp", argv...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return exitError
	}
	return exitOK
}
