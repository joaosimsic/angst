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

func usageBootstrapPassword() {
	fmt.Print(`Usage:
  angst bootstrap-password --name NAME --scope personal|work

Writes secrets/password/<name>.age. The host declaration selects the password
by name; the scope only chooses the age key used for encryption.
`)
}

func BootstrapPassword(args []string) int {
	repoRoot := paths.RepoRoot()
	name := ""
	scopeFlag := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--name":
			if i+1 < len(args) {
				name = args[i+1]
				i++
			}
		case "--scope":
			if i+1 < len(args) {
				scopeFlag = args[i+1]
				i++
			}
		case "-h", "--help":
			usageBootstrapPassword()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown bootstrap-password option: %s\n", args[i])
			usageBootstrapPassword()
			return exitUsage
		}
	}

	if name == "" || strings.Contains(name, "/") || name == "." || name == ".." {
		fmt.Fprintln(os.Stderr, "Error: --name must be a plain password name")
		return exitUsage
	}
	if !scope.Valid(scopeFlag) {
		fmt.Fprintf(os.Stderr, "Error: invalid --scope '%s' (expected personal|work)\n", scopeFlag)
		return exitUsage
	}
	sc := scope.Scope(scopeFlag)

	if _, err := exec.LookPath("age"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: age is not available. Install it first (e.g., nix shell nixpkgs#age)")
		return exitError
	}
	if _, err := exec.LookPath("age-keygen"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: age-keygen is not available. Install it first (e.g., nix shell nixpkgs#age)")
		return exitError
	}

	password, err := readSecret("Password: ")
	if err != nil {
		return exitError
	}
	if password == "" {
		fmt.Fprintln(os.Stderr, "Error: password cannot be empty")
		return exitError
	}
	confirm, err := readSecret("Confirm password: ")
	if err != nil {
		return exitError
	}
	if password != confirm {
		fmt.Fprintln(os.Stderr, "Error: passwords do not match")
		return exitError
	}

	keyFile := scope.AgeKeyfile(sc, scope.Fixed)
	recipient, err := scope.Recipient(keyFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: could not derive age recipient from %s: %v\n", keyFile, err)
		return exitError
	}

	outDir := filepath.Join(repoRoot, "secrets", "password")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: could not create %s\n", outDir)
		return exitError
	}
	outPath := filepath.Join(outDir, name+".age")

	tmp, err := os.CreateTemp("", "angst-password-*.txt")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error: could not create temp file")
		return exitError
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if _, err := tmp.WriteString(password); err != nil {
		fmt.Fprintln(os.Stderr, "Error: could not write temp file")
		return exitError
	}
	tmp.Close()

	if err := shared.AgeEncrypt(keyFile, recipient, tmpName, outPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to encrypt password: %v\n", err)
		return exitError
	}
	_ = os.Chmod(outPath, 0o600)

	fmt.Printf("Password encrypted for %s (scope %s):\n", name, sc)
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

func usageSetPasswordHash() {
	fmt.Print(`Usage:
  angst set-password-hash --username USER --age-path FILE --scopes personal,work [--home DIR] [--age-key FILE]

Tries the age keys for the declared scopes in order. Missing files or keys are
non-fatal: the fallback password hash is kept.
`)
}

func passwordKeyFiles(ageKey, scopesFlag, homeDir string) ([]string, bool) {
	if ageKey != "" {
		return []string{ageKey}, true
	}
	requested := scope.Split(scopesFlag)
	if len(requested) == 0 {
		return nil, false
	}
	keys := make([]string, 0, len(requested))
	for _, sc := range requested {
		keys = append(keys, scope.AgeKeyfileInHome(homeDir, sc, scope.Fixed))
	}
	return keys, true
}

func SetPasswordHash(args []string) int {
	username := ""
	agePath := ""
	ageKey := ""
	scopesFlag := ""
	homeDir := ""
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
		case "--scopes":
			if i+1 < len(args) {
				scopesFlag = args[i+1]
				i++
			}
		case "--home":
			if i+1 < len(args) {
				homeDir = args[i+1]
				i++
			}
		case "-h", "--help":
			usageSetPasswordHash()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown set-password-hash option: %s\n", args[i])
			return exitUsage
		}
	}
	if username == "" || agePath == "" {
		fmt.Fprintln(os.Stderr, "error: set-password-hash requires --username and --age-path")
		return exitUsage
	}
	if homeDir == "" {
		homeDir = filepath.Join("/home", username)
	}

	keyFiles, ok := passwordKeyFiles(ageKey, scopesFlag, homeDir)
	if !ok {
		fmt.Fprintln(os.Stderr, "error: set-password-hash requires --scopes or --age-key")
		return exitUsage
	}

	if _, err := os.Stat(agePath); err != nil {
		fmt.Fprintf(os.Stderr, "warn: password file %s is missing; keeping fallback hash\n", agePath)
		return exitOK
	}

	tmpDir, err := os.MkdirTemp("", "angst-pwhash-")
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: could not create temp dir")
		return exitError
	}
	defer os.RemoveAll(tmpDir)

	for _, keyFile := range keyFiles {
		if _, err := os.Stat(keyFile); err != nil {
			continue
		}
		tmpName := filepath.Join(tmpDir, "pw")
		_ = os.Remove(tmpName)
		if err := shared.AgeDecrypt(keyFile, agePath, tmpName); err != nil {
			_ = os.Remove(tmpName)
			continue
		}
		pass, err := os.ReadFile(tmpName)
		if err != nil {
			fmt.Fprintln(os.Stderr, "error: could not read decrypted password")
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

	fmt.Fprintf(os.Stderr, "warn: could not decrypt %s with any declared scope key; keeping fallback hash\n", agePath)
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
