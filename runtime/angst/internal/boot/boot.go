package boot

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"angst/internal/cmd"
	"angst/internal/paths"
	"angst/internal/shared"
)

const (
	exitUsage = shared.ExitUsage
	exitError = shared.ExitError
	exitOK    = shared.ExitOK
)

func usage() {
	fmt.Print(`Usage:
  angst bootstrap-secrets [--host HOST]
`)
}

// BootstrapSecrets implements the interactive `angst bootstrap-secrets`.
func BootstrapSecrets(args []string) int {
	repoRoot := paths.RepoRoot()
	hostName := "nixos"

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--host":
			if i+1 < len(args) {
				hostName = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown bootstrap-secrets option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}

	if _, err := exec.LookPath("sops"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: sops is not available. Install it first (e.g., nix shell nixpkgs#sops)")
		return exitError
	}
	if _, err := exec.LookPath("mkpasswd"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: mkpasswd is not available. Install whois or use nix environment.")
		return exitError
	}

	configDir, ok := paths.FindHostConfigDir(repoRoot, hostName)
	if !ok {
		fmt.Fprintf(os.Stderr, "Error: host config not found for '%s'\n", hostName)
		return exitError
	}
	secretsFile := filepath.Join(configDir, "secrets.yaml")
	configFile := filepath.Join(configDir, "default.nix")
	if _, err := os.Stat(configFile); err != nil {
		fmt.Fprintf(os.Stderr, "Error: host config not found for '%s'\n", hostName)
		return exitError
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

	hash, err := cmd.Output("mkpasswd", "-m", "sha-512", master)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error: failed to hash password")
		return exitError
	}

	data := []byte(fmt.Sprintf("masterPassword: \"%s\"\n", master))
	sc := exec.Command("sops", "--input-type", "yaml", "--output-type", "yaml", secretsFile)
	sc.Stdin = bytes.NewReader(data)
	sc.Stdout = os.Stdout
	sc.Stderr = nil
	if err := sc.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to %s %s\n", upsertWord(secretsFile), secretsFile)
		return exitError
	}

	if err := setPasswordField(configFile, hash); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to update %s\n", configFile)
		return exitError
	}

	fmt.Printf("Secrets bootstrapped for %s:\n", hostName)
	fmt.Printf("  secrets: %s\n", secretsFile)
	fmt.Printf("  hash:    %s\n", configFile)
	fmt.Println("")
	fmt.Println("Run 'sudo nixos-rebuild switch --flake .#" + hostName + "' to apply.")
	return exitOK
}

func upsertWord(path string) string {
	if _, err := os.Stat(path); err != nil {
		return "create"
	}
	return "update"
}

func setPasswordField(configFile, hash string) error {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return err
	}
	re := regexp.MustCompile(`(?m)^\s*password\s*=`)
	if re.Match(data) {
		repl := regexp.MustCompile(`(?m)^(\s*)password\s*=.*`)
		out := repl.ReplaceAllString(string(data), fmt.Sprintf(`${1}password = "%s";`, hash))
		return os.WriteFile(configFile, []byte(out), 0o644)
	}
	closeRe := regexp.MustCompile(`(?m)^\s*}[\s;]*$`)
	idxs := closeRe.FindAllStringIndex(string(data), -1)
	if len(idxs) == 0 {
		return nil
	}
	at := idxs[len(idxs)-1][0]
	line := fmt.Sprintf(`  password = "%s";`, hash)
	var b strings.Builder
	b.Write(data[:at])
	b.WriteString(line)
	b.WriteString("\n")
	b.Write(data[at:])
	return os.WriteFile(configFile, []byte(b.String()), 0o644)
}

func readSecret(prompt string) (string, error) {
	fmt.Print(prompt)
	_ = exec.Command("stty", "-echo").Run()
	defer func() {
		_ = exec.Command("stty", "echo").Run()
		fmt.Println()
	}()
	reader := bufio.NewReader(os.Stdin)
	line, err := reader.ReadString('\n')
	if err != nil && line == "" {
		return "", err
	}
	return strings.TrimRight(line, "\r\n"), nil
}

// SetPasswordHash implements the baked `set-password-hash` service command.
func SetPasswordHash(args []string) int {
	username := ""
	sopsPath := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--username":
			if i+1 < len(args) {
				username = args[i+1]
				i++
			}
		case "--sops-path":
			if i+1 < len(args) {
				sopsPath = args[i+1]
				i++
			}
		default:
			fmt.Fprintf(os.Stderr, "unknown set-password-hash option: %s\n", args[i])
			return exitUsage
		}
	}
	if username == "" || sopsPath == "" {
		fmt.Fprintln(os.Stderr, "error: set-password-hash requires --username and --sops-path")
		return exitUsage
	}

	pass, err := os.ReadFile(sopsPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not read %s\n", sopsPath)
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
