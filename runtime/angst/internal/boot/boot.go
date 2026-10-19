package boot

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"angst/internal/cmd"
	"angst/internal/paths"
	"angst/internal/scope"
	"angst/internal/shared"
)

const (
	exitUsage = shared.ExitUsage
	exitError = shared.ExitError
	exitOK    = shared.ExitOK
)

func usageMasterPassword() {
	fmt.Print(`Usage:
  angst bootstrap-master-password [--host HOST] [--scope personal|work]
`)
}

func BootstrapMasterPassword(args []string) int {
	repoRoot := paths.RepoRoot()
	hostName := "nixos"
	scopeFlag := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--host":
			if i+1 < len(args) {
				hostName = args[i+1]
				i++
			}
		case "--scope":
			if i+1 < len(args) {
				scopeFlag = args[i+1]
				i++
			}
		case "-h", "--help":
			usageMasterPassword()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown bootstrap-master-password option: %s\n", args[i])
			usageMasterPassword()
			return exitUsage
		}
	}

	if _, err := exec.LookPath("age"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: age is not available. Install it first (e.g., nix shell nixpkgs#age)")
		return exitError
	}
	if _, err := exec.LookPath("age-keygen"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: age-keygen is not available. Install it first (e.g., nix shell nixpkgs#age)")
		return exitError
	}

	configDir, ok := paths.FindHostConfigDir(repoRoot, hostName)
	if !ok {
		fmt.Fprintf(os.Stderr, "Error: host config not found for '%s'\n", hostName)
		return exitError
	}
	configFile := filepath.Join(configDir, "default.nix")
	if _, err := os.Stat(configFile); err != nil {
		fmt.Fprintf(os.Stderr, "Error: host config not found for '%s'\n", hostName)
		return exitError
	}

	sc := scope.Personal
	if scopeFlag != "" {
		if !scope.Valid(scopeFlag) {
			fmt.Fprintf(os.Stderr, "Error: invalid --scope '%s' (expected personal|work)\n", scopeFlag)
			return exitUsage
		}
		sc = scope.Scope(scopeFlag)
	} else if strings.Contains(configDir, "/work/") {
		sc = scope.Work
	}

	master, err := readSecret("Master password: ")
	if err != nil {
		return exitError
	}
	if master == "" {
		fmt.Fprintln(os.Stderr, "Error: password cannot be empty")
		return exitError
	}
	confirm, err := readSecret("Confirm master password: ")
	if err != nil {
		return exitError
	}
	if master != confirm {
		fmt.Fprintln(os.Stderr, "Error: passwords do not match")
		return exitError
	}

	keyFile := scope.AgeKeyfile(sc, scope.Fixed)
	recipient, err := scope.Recipient(keyFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: could not derive age recipient from %s: %v\n", keyFile, err)
		return exitError
	}

	outDir := filepath.Join(repoRoot, "secrets", "master")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: could not create %s\n", outDir)
		return exitError
	}
	outPath := filepath.Join(outDir, hostName+".age")

	tmp, err := os.CreateTemp("", "angst-master-*.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error: could not create temp file")
		return exitError
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if _, err := tmp.WriteString(master); err != nil {
		fmt.Fprintln(os.Stderr, "Error: could not write temp file")
		return exitError
	}
	tmp.Close()

	if err := shared.AgeEncrypt(keyFile, recipient, tmpName, outPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to encrypt master password: %v\n", err)
		return exitError
	}

	fmt.Printf("Master password encrypted for %s (scope %s):\n", hostName, sc)
	fmt.Printf("  age file: %s\n", outPath)
	fmt.Println("")
	fmt.Println("Rebuild the host to apply (the boot service derives the login hash).")
	return exitOK
}

func readSecret(prompt string) (string, error) {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return "", fmt.Errorf("cannot open terminal to read password securely: %v", err)
	}
	defer tty.Close()

	if err := exec.Command("stty", "-F", "/dev/tty", "-echo").Run(); err != nil {
		fmt.Fprintln(tty, "warning: could not disable terminal echo; password may be visible")
	}
	fmt.Fprint(tty, prompt)
	reader := bufio.NewReader(tty)
	line, err := reader.ReadString('\n')
	_ = exec.Command("stty", "-F", "/dev/tty", "echo").Run()
	fmt.Fprintln(tty)
	if err != nil && line == "" {
		return "", err
	}
	return strings.TrimRight(line, "\r\n"), nil
}

func SetPasswordHash(args []string) int {
	username := ""
	agePath := ""
	ageKey := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--username":
			if i+1 < len(args) {
				username = args[i+1]
				i++
			}
		case "--age-path":
			if i+1 < len(args) {
				agePath = args[i+1]
				i++
			}
		case "--age-key":
			if i+1 < len(args) {
				ageKey = args[i+1]
				i++
			}
		default:
			fmt.Fprintf(os.Stderr, "unknown set-password-hash option: %s\n", args[i])
			return exitUsage
		}
	}
	if username == "" || agePath == "" || ageKey == "" {
		fmt.Fprintln(os.Stderr, "error: set-password-hash requires --username, --age-path and --age-key")
		return exitUsage
	}

	tmpDir, err := os.MkdirTemp("", "angst-pwhash-")
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: could not create temp dir")
		return exitError
	}
	defer os.RemoveAll(tmpDir)
	tmpName := filepath.Join(tmpDir, "pw")

	if err := shared.AgeDecrypt(ageKey, agePath, tmpName); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not decrypt %s: %v\n", agePath, err)
		return exitError
	}
	pass, err := os.ReadFile(tmpName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not read decrypted password\n")
		return exitError
	}
	feed := append(append([]byte{}, pass...), '\n')
	hash, err := hashPassword(feed)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: failed to hash password")
		return exitError
	}
	if err := cmd.Run("usermod", "-p", hash, username); err != nil {
		return exitError
	}
	if err := cmd.Run("usermod", "-p", hash, "root"); err != nil {
		return exitError
	}
	return exitOK
}

func hashPassword(pass []byte) (string, error) {
	c := exec.Command("mkpasswd", "-m", "sha-512", "-s")
	c.Stdin = bytes.NewReader(pass)
	c.Stderr = os.Stderr
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return "", err
	}
	return strings.TrimRight(out.String(), "\n"), nil
}
