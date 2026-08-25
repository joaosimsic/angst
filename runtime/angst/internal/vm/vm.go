package vm

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"

	"angst/internal/cmd"
	"angst/internal/shared"
)

const (
	exitUsage = shared.ExitUsage
	exitError = shared.ExitError
	exitOK    = shared.ExitOK
)

func usage() {
	fmt.Print(`Usage:
  angst vm age-key --user USER --home DIR [--inject-work-key]
  angst vm ephemeral-ssh --mountpoint-bin P --mount-bin P --rm-bin P --cp-bin P --mkdir-bin P
  angst vm home-manager-upgrade --user USER
  angst vm nixos-switch [FLAKE_REF]
  angst vm home-switch [FLAKE_REF]
  angst vm start [--headless]
  angst vm stop
  angst vm restart [--headless]
  angst vm status
  angst vm health
  angst vm logs [-n LINES]
  angst vm ssh [--auto-start] [-t] [-- COMMAND...]
  angst vm exec -- COMMAND...
  angst vm copy-to <src> <dest>
  angst vm copy-from <src> <dest>
  angst vm mcp <start|stop|restart|status|logs|run-server>
`)
}

func Run(args []string) int {
	sub := ""
	if len(args) > 0 {
		sub = args[0]
		args = args[1:]
	}
	switch sub {
	case "age-key":
		return ageKey(args)
	case "ephemeral-ssh":
		return ephemeralSsh(args)
	case "home-manager-upgrade":
		return homeManagerUpgrade(args)
	case "nixos-switch":
		return nixosSwitch(args)
	case "home-switch":
		return homeSwitch(args)
	case "start":
		return start(args)
	case "stop":
		return stop(args)
	case "restart":
		return restart(args)
	case "status":
		return status(args)
	case "health":
		return health(args)
	case "logs":
		return logsCmd(args)
	case "ssh":
		return sshCmd(args)
	case "exec":
		return execCmd(args)
	case "copy-to":
		return copyToCmd(args)
	case "copy-from":
		return copyFromCmd(args)
	case "mcp":
		return mcpDispatch(args)
	case "", "-h", "--help":
		usage()
		return exitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown vm command: %s\n", sub)
		usage()
		return exitUsage
	}
}

func parseFlags(args []string, flags map[string]*string) {
	for i := 0; i < len(args); i++ {
		name := args[i]
		if v, ok := flags[name]; ok {
			if i+1 < len(args) {
				*v = args[i+1]
				i++
			}
		}
	}
}

func ageKey(args []string) int {
	username := ""
	homeDir := ""
	inject := false
	flags := map[string]*string{"--user": &username, "--home": &homeDir}
	parseFlags(args, flags)
	for _, a := range args {
		if a == "--inject-work-key" {
			inject = true
		}
		if a == "-h" || a == "--help" {
			usage()
			return exitOK
		}
	}
	if username == "" || homeDir == "" {
		fmt.Fprintln(os.Stderr, "error: age-key requires --user and --home")
		return exitUsage
	}

	keyFile := "/tmp/shared/age-keys.txt"
	if st, err := os.Stat(keyFile); err != nil || st.Size() == 0 {
		fmt.Fprintln(os.Stdout, "No host age key found at /tmp/shared/age-keys.txt; secrets will be unavailable.")
		return exitOK
	}
	ageDir := filepath.Join(homeDir, ".config", "age")
	if err := cmd.Run("install", "-d", "-m", "700", "-o", username, "-g", "users", ageDir); err != nil {
		return exitError
	}
	if err := cmd.Run("install", "-m", "600", "-o", username, "-g", "users", keyFile, filepath.Join(ageDir, "keys.txt")); err != nil {
		return exitError
	}
	if inject {
		workKey := "/tmp/shared/work-keys.txt"
		if st, err := os.Stat(workKey); err != nil || st.Size() == 0 {
			fmt.Fprintln(os.Stderr, "warn: work age key requested but not found at /tmp/shared/work-keys.txt")
		} else {
			if err := cmd.Run("install", "-m", "600", "-o", username, "-g", "users", workKey, filepath.Join(ageDir, "work-keys.txt")); err != nil {
				return exitError
			}
		}
	}
	return exitOK
}

func ephemeralSsh(args []string) int {
	mountpointBin := ""
	mountBin := ""
	rmBin := ""
	cpBin := ""
	mkdirBin := ""
	flags := map[string]*string{
		"--mountpoint-bin": &mountpointBin,
		"--mount-bin":      &mountBin,
		"--rm-bin":         &rmBin,
		"--cp-bin":         &cpBin,
		"--mkdir-bin":      &mkdirBin,
	}
	parseFlags(args, flags)
	for _, b := range flags {
		if *b == "" {
			fmt.Fprintln(os.Stderr, "error: ephemeral-ssh requires absolute tool paths (baked by the wrapper)")
			return exitUsage
		}
	}

	if err := cmd.Run(mountpointBin, "-q", "/etc/ssh"); err != nil {
		if err2 := cmd.Run(mountBin, "-t", "tmpfs", "tmpfs", "/etc/ssh", "-o", "mode=0755"); err2 != nil {
			return exitError
		}
	}
	for _, f := range []string{"/run/current-system/etc/ssh/sshd_config", "/etc/static/ssh/sshd_config"} {
		if _, err := os.Stat(f); err != nil || !isRegular(f) {
			continue
		}
		_ = cmd.Run(rmBin, "-f", "/etc/ssh/sshd_config")
		if err := cmd.Run(cpBin, f, "/etc/ssh/sshd_config"); err != nil {
			return exitError
		}
		break
	}
	for _, d := range []string{"/run/current-system/etc/ssh/authorized_keys.d", "/etc/static/ssh/authorized_keys.d"} {
		if st, err := os.Stat(d); err != nil || !st.IsDir() {
			continue
		}
		_ = cmd.Run(mkdirBin, "-p", "/etc/ssh/authorized_keys.d")
		entries, _ := filepath.Glob(filepath.Join(d, "*"))
		for _, f := range entries {
			base := filepath.Base(f)
			if suffix := filepath.Ext(base); suffix == ".uid" || suffix == ".gid" || suffix == ".mode" {
				continue
			}
			if !isRegular(f) {
				continue
			}
			dst := filepath.Join("/etc/ssh/authorized_keys.d", base)
			_ = cmd.Run(rmBin, "-f", dst)
			if err := cmd.Run(cpBin, f, dst); err != nil {
				return exitError
			}
		}
		break
	}
	return exitOK
}

func isRegular(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.Mode().IsRegular()
}

var execStartRe = regexp.MustCompile(`^.* ([^ ]*)-home-manager-generation.*$`)

func homeManagerUpgrade(args []string) int {
	username := ""
	flags := map[string]*string{"--user": &username}
	parseFlags(args, flags)
	if username == "" {
		fmt.Fprintln(os.Stderr, "error: home-manager-upgrade requires --user")
		return exitUsage
	}

	service, _ := cmd.OutputRaw("systemctl", "show", "home-manager-"+username, "-p", "ExecStart")
	activeGen := ""
	if m := execStartRe.FindStringSubmatch(string(service)); m != nil {
		activeGen = m[1] + "-home-manager-generation"
	}
	activeHP := ""
	if activeGen != "" {
		if resolved, err := filepath.EvalSymlinks(filepath.Join(activeGen, "home-path")); err == nil {
			if st, err := os.Stat(resolved); err == nil && st.IsDir() {
				activeHP = resolved
			}
		}
	}
	if activeHP == "" {
		fmt.Println("Could not determine active home-manager-path; nothing to upgrade.")
		return exitOK
	}

	matches, err := filepath.Glob("/nix/store/*-home-manager-generation/activate")
	if err != nil {
		return exitOK
	}
	latest := ""
	for _, gen := range matches {
		if !isRegular(gen) {
			continue
		}
		dir := strings.TrimSuffix(gen, "/activate")
		hp, err := filepath.EvalSymlinks(filepath.Join(dir, "home-path"))
		if err != nil {
			continue
		}
		if hp == activeHP {
			continue
		}
		if st, err := os.Stat(hp); err != nil || !st.IsDir() {
			continue
		}
		latest = dir
	}
	if latest != "" {
		if st, err := os.Stat(filepath.Join(latest, "activate")); err == nil && st.Mode().Perm()&0o111 != 0 {
			_ = cmd.Run(filepath.Join(latest, "activate"), "--driver-version", "1")
		}
	}
	return exitOK
}

func nixosSwitch(args []string) int {
	if os.Geteuid() != 0 {
		fmt.Fprintln(os.Stderr, "vm-nixos-switch: must be run as root (sudo).")
		return exitError
	}
	flakeRef := "."
	if len(args) > 0 && args[0] != "-h" && args[0] != "--help" {
		flakeRef = args[0]
	}
	sys, err := cmd.Output("nix", "build", "--no-link", "--print-out-paths",
		flakeRef+"#nixosConfigurations.vm.config.virtualisation.vmVariant.system.build.toplevel")
	if err != nil {
		return exitError
	}
	if err := cmd.Run("nix-env", "-p", "/nix/var/nix/profiles/system", "--set", sys); err != nil {
		return exitError
	}
	return execOrRun(filepath.Join(sys, "bin", "switch-to-configuration"), "switch")
}

func homeSwitch(args []string) int {
	flakeRef := "."
	if len(args) > 0 && args[0] != "-h" && args[0] != "--help" {
		flakeRef = args[0]
	}
	gen, err := cmd.Output("nix", "build", "--no-link", "--print-out-paths",
		flakeRef+"#homeConfigurations.vm.activationPackage")
	if err != nil {
		return exitError
	}
	return execOrRun(filepath.Join(gen, "activate"), "--driver-version", "1")
}

func execOrRun(path string, args ...string) int {
	full := append([]string{path}, args...)
	env := os.Environ()
	if err := syscall.Exec(path, full, env); err != nil {
		return exitError
	}
	return exitOK
}
