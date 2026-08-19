package system

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"angst/internal/shared"
)

func LoginShell(args []string) int {
	shellName := ""
	homeDir := ""
	username := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--shell":
			if i+1 < len(args) {
				shellName = args[i+1]
				i++
			}
		case "--home":
			if i+1 < len(args) {
				homeDir = args[i+1]
				i++
			}
		case "--user":
			if i+1 < len(args) {
				username = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown login-shell option: %s\n", args[i])
			return shared.ExitUsage
		}
	}

	verbose := os.Getenv("VERBOSE_ECHO")
	dryRun := os.Getenv("DRY_RUN_CMD")

	sh := func(parts ...string) int {
		joined := strings.Join(parts, " ")
		c := exec.Command("sh", "-c", joined)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		err := c.Run()
		if err == nil {
			return shared.ExitOK
		}
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return shared.ExitError
	}

	if _, err := os.Stat("/etc/NIXOS"); err == nil {
		return sh(verbose, quote("angst: NixOS detected, login shell managed by NixOS config"))
	}

	resolved := ""
	for _, candidate := range []string{
		filepath.Join(homeDir, ".nix-profile", "bin", shellName),
		"/usr/local/bin/" + shellName,
		"/usr/bin/" + shellName,
		"/bin/" + shellName,
	} {
		if isExecutable(candidate) {
			resolved = candidate
			break
		}
	}
	if resolved == "" {
		return sh(verbose, quote("angst: shell '"+shellName+"' not found, skipping"))
	}

	priv := ""
	if os.Geteuid() != 0 {
		switch {
		case lookPath("sudo") != "":
			priv = "sudo"
		case isExecutable("/usr/bin/sudo"):
			priv = "/usr/bin/sudo"
		case isExecutable("/usr/local/bin/sudo"):
			priv = "/usr/local/bin/sudo"
		default:
			return sh(verbose, quote("angst: cannot set login shell: neither root nor sudo available"))
		}
	}

	chshCmd := ""
	switch {
	case lookPath("chsh") != "":
		chshCmd = "chsh"
	case isExecutable("/usr/bin/chsh"):
		chshCmd = "/usr/bin/chsh"
	default:
		return sh(verbose, quote("angst: chsh not found, skipping login shell setup"))
	}

	escalate := func(inner ...string) string {
		if priv == "" {
			return strings.Join(inner, " ")
		}
		return dash(priv, inner...)
	}

	shells := readLines("/etc/shells")
	if !containsLine(shells, resolved) {
		_ = sh(verbose, quote("angst: adding "+resolved+" to /etc/shells..."))
		innerScript := singleQuote(`printf "%s\n" "$1" | tee -a /etc/shells > /dev/null`)
		inner := "sh -c " + innerScript + " _ " + quote(resolved)
		_ = sh(dryRun, escalate(inner))
	}

	current := currentShell(username)
	if current != resolved {
		_ = sh(verbose, quote("angst: setting login shell to "+resolved+"..."))
		inner := dash(chshCmd, "-s", quote(resolved), quote(username))
		_ = sh(dryRun, escalate(inner))
	}
	return shared.ExitOK
}

func currentShell(username string) string {
	data, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return ""
	}
	prefix := username + ":"
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, prefix) {
			fields := strings.Split(line, ":")
			if len(fields) >= 7 {
				return fields[6]
			}
		}
	}
	return ""
}
