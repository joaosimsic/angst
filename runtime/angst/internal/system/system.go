package system

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"angst/internal/cmd"
)

const (
	exitUsage = 2
	exitError = 1
	exitOK    = 0
)

func usage() {
	fmt.Print(`Usage:
  angst login-shell --shell NAME --home DIR --user USER
  angst ssh-add-keys KEY...
  angst provision-ssh-key --user USER --home DIR --secrets-dir DIR
`)
}

func dash(first string, rest ...string) string {
	s := first
	for _, r := range rest {
		s += " " + r
	}
	return s
}

func quietRun(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = nil
	return c.Run()
}

// LoginShell implements `angst login-shell`.
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
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown login-shell option: %s\n", args[i])
			return exitUsage
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
			return exitOK
		}
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return exitError
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
	return exitOK
}

func quote(s string) string {
	return strconv.Quote(s)
}

func singleQuote(s string) string {
	return "'" + s + "'"
}

func isExecutable(path string) bool {
	if st, err := os.Stat(path); err == nil {
		return st.Mode().IsRegular() && st.Mode().Perm()&0o111 != 0
	}
	return false
}

func lookPath(name string) string {
	p, err := exec.LookPath(name)
	if err != nil {
		return ""
	}
	return p
}

func readLines(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	return strings.Split(strings.TrimRight(string(data), "\n"), "\n")
}

func containsLine(lines []string, needle string) bool {
	for _, l := range lines {
		if l == needle {
			return true
		}
	}
	return false
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

// SSHAddKeys implements the baked `ssh-add-keys` service command.
func SSHAddKeys(args []string) int {
	for _, key := range args {
		if _, err := os.Stat(key); err != nil {
			continue
		}
		lf, err := cmd.Output("ssh-keygen", "-lf", key)
		if err != nil {
			continue
		}
		fields := strings.Fields(lf)
		if len(fields) < 2 {
			continue
		}
		fp := fields[1]
		added, err := cmd.Output("ssh-add", "-l")
		if err == nil && strings.Contains(added, fp) {
			continue
		}
		_ = quietRun("ssh-add", key)
	}
	return exitOK
}

// ProvisionSSHKey implements the baked `provision-ssh-key` service command.
func ProvisionSSHKey(args []string) int {
	username := ""
	homeDir := ""
	secretsDir := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--user":
			if i+1 < len(args) {
				username = args[i+1]
				i++
			}
		case "--home":
			if i+1 < len(args) {
				homeDir = args[i+1]
				i++
			}
		case "--secrets-dir":
			if i+1 < len(args) {
				secretsDir = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown provision-ssh-key option: %s\n", args[i])
			return exitUsage
		}
	}

	_ = syscall.Umask(0o077)
	sshDir := filepath.Join(homeDir, ".ssh")
	tmp, err := os.MkdirTemp("", "angst-sshprov-")
	if err != nil {
		return exitError
	}
	defer os.RemoveAll(tmp)

	provision := func(scope, ageKey, dest string) int {
		ageFile := filepath.Join(secretsDir, scope+".ed25519.age")
		if _, err := os.Stat(ageKey); err != nil {
			return exitOK
		}
		if _, err := os.Stat(ageFile); err != nil {
			return exitOK
		}
		plain := filepath.Join(tmp, scope+".key")
		if err := ageDecrypt(ageKey, ageFile, plain); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s; skipping %s SSH key\n", ageFile, scope)
			return exitOK
		}
		_ = os.Chmod(plain, 0o600)

		pub, err := cmd.Output("ssh-keygen", "-y", "-f", plain)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warn: decrypted %s key is invalid; leaving existing %s untouched\n", scope, dest)
			return exitOK
		}
		pubPath := filepath.Join(tmp, scope+".pub")
		_ = os.WriteFile(pubPath, []byte(pub+"\n"), 0o600)

		tmpInstall := filepath.Join(sshDir, dest+".tmp")
		tmpPub := filepath.Join(sshDir, dest+".pub.tmp")
		root := os.Geteuid() == 0
		if root {
			if err := cmd.Run("install", "-d", "-m", "700", "-o", username, "-g", "users", sshDir); err != nil {
				return exitError
			}
			if err := cmd.Run("install", "-m", "600", "-o", username, "-g", "users", plain, tmpInstall); err != nil {
				return exitError
			}
			if err := cmd.Run("install", "-m", "644", "-o", username, "-g", "users", pubPath, tmpPub); err != nil {
				return exitError
			}
		} else {
			if err := cmd.Run("install", "-d", "-m", "700", sshDir); err != nil {
				return exitError
			}
			if err := cmd.Run("install", "-m", "600", plain, tmpInstall); err != nil {
				return exitError
			}
			if err := cmd.Run("install", "-m", "644", pubPath, tmpPub); err != nil {
				return exitError
			}
		}
		_ = os.Rename(tmpInstall, filepath.Join(sshDir, dest))
		_ = os.Rename(tmpPub, filepath.Join(sshDir, dest+".pub"))
		_ = os.Remove(plain)
		fmt.Printf("provisioned %s SSH key -> %s/%s\n", scope, sshDir, dest)
		return exitOK
	}

	code := provision("personal", filepath.Join(homeDir, ".config", "sops", "age", "keys.txt"), "id_ed25519")
	if code != exitOK {
		return code
	}
	return provision("work", filepath.Join(homeDir, ".config", "sops", "age", "work-keys.txt"), "work_ed25519")
}

func ageDecrypt(keyfile, in, out string) error {
	c := exec.Command("age", "-d", "-i", keyfile, "-o", out, in)
	c.Stderr = nil
	return c.Run()
}
