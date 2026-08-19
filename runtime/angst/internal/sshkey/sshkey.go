package sshkey

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/cmd"
	"angst/internal/paths"
	"angst/internal/shared"
	"angst/internal/scope"
)

const (
	exitUsage = shared.ExitUsage
	exitError = shared.ExitError
	exitOK    = shared.ExitOK
)

func usage() {
	fmt.Print(`Usage:
  angst ssh-key generate --scope personal|work
  angst ssh-key verify   --scope personal|work
`)
}

// Run dispatches `angst ssh-key <cmd>` and returns the process exit code.
func Run(args []string) int {
	sub := ""
	if len(args) > 0 {
		sub = args[0]
		args = args[1:]
	}
	switch sub {
	case "generate":
		return generate(args)
	case "verify":
		return verify(args)
	case "", "-h", "--help":
		usage()
		return exitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown ssh-key command: %s\n", sub)
		usage()
		return exitUsage
	}
}

func parseScope(args []string) (string, int) {
	sc := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--scope":
			if i+1 >= len(args) || args[i+1] == "" {
				fmt.Fprintln(os.Stderr, "error: --scope requires a value (personal|work)")
				return "", exitUsage
			}
			sc = args[i+1]
			i++
		case "-h", "--help":
			usage()
			return "", exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown ssh-key option: %s\n", args[i])
			usage()
			return "", exitUsage
		}
	}
	switch scope.Scope(sc) {
	case scope.Personal, scope.Work:
		return sc, exitOK
	case "":
		fmt.Fprintln(os.Stderr, "error: invalid scope '' (personal|work)")
		usage()
		return "", exitUsage
	default:
		fmt.Fprintf(os.Stderr, "error: invalid scope '%s' (personal|work)\n", sc)
		usage()
		return "", exitUsage
	}
}

func generate(args []string) int {
	sc, code := parseScope(args)
	if code != exitOK {
		return code
	}
	s := scope.Scope(sc)
	keyfile := scope.AgeKeyfile(s, scope.Fixed)
	if _, err := os.Stat(keyfile); err != nil {
		fmt.Fprintf(os.Stderr, "error: no %s age key at %s\n", s, keyfile)
		return exitError
	}
	recipient, err := scope.Recipient(keyfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: could not derive the %s age recipient from %s\n", s, keyfile)
		return exitError
	}

	dir := filepath.Join(paths.RepoRoot(), "secrets", "ssh")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return exitError
	}
	tmp, err := os.MkdirTemp("", "angst-sshkey-")
	if err != nil {
		return exitError
	}
	defer os.RemoveAll(tmp)

	if err := cmd.Run("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", filepath.Join(tmp, "sshkey"), "-C", "angst-"+sc); err != nil {
		return exitError
	}
	ageFile := filepath.Join(dir, sc+".ed25519.age")
	if err := cmd.Run("age", "-r", recipient, "-o", ageFile, filepath.Join(tmp, "sshkey")); err != nil {
		fmt.Fprintf(os.Stderr, "error: age encryption failed (recipient %s)\n", recipient)
		return exitError
	}
	pubFile := filepath.Join(dir, sc+".ed25519.pub")
	if err := cmd.Run("cp", filepath.Join(tmp, "sshkey.pub"), pubFile); err != nil {
		return exitError
	}
	_ = os.Chmod(pubFile, 0o644)

	pub, _ := os.ReadFile(pubFile)
	fmt.Printf("generated %s SSH key:\n", sc)
	fmt.Printf("  private (age-encrypted): %s\n", ageFile)
	fmt.Printf("  public (committed):      %s\n", pubFile)
	fmt.Printf("\npublic key: %s", pub)
	fmt.Print("\n")
	fmt.Printf("\nauthorize it at the %s provider, then run:\n", sc)
	fmt.Printf("  angst ssh-key verify --scope %s\n", sc)
	return exitOK
}

func verify(args []string) int {
	sc, code := parseScope(args)
	if code != exitOK {
		return code
	}
	s := scope.Scope(sc)
	keyfile := scope.AgeKeyfile(s, scope.Fixed)

	dir := filepath.Join(paths.RepoRoot(), "secrets", "ssh")
	ageFile := filepath.Join(dir, sc+".ed25519.age")
	pubFile := filepath.Join(dir, sc+".ed25519.pub")
	if _, err := os.Stat(keyfile); err != nil {
		fmt.Fprintf(os.Stderr, "error: no %s age key at %s\n", s, keyfile)
		return exitError
	}
	if _, err := os.Stat(ageFile); err != nil {
		fmt.Fprintf(os.Stderr, "error: missing %s/%s.ed25519.{age,pub}; run 'angst ssh-key generate --scope %s' first\n", dir, sc, sc)
		return exitError
	}
	if _, err := os.Stat(pubFile); err != nil {
		fmt.Fprintf(os.Stderr, "error: missing %s/%s.ed25519.{age,pub}; run 'angst ssh-key generate --scope %s' first\n", dir, sc, sc)
		return exitError
	}

	tmp, err := os.MkdirTemp("", "angst-sshkey-")
	if err != nil {
		return exitError
	}
	defer os.RemoveAll(tmp)

	key := filepath.Join(tmp, "sshkey")
	if err := shared.AgeDecrypt(keyfile, ageFile, key); err != nil {
		fmt.Fprintf(os.Stderr, "FAIL: could not decrypt %s with the %s age key\n", ageFile, sc)
		return exitError
	}
	_ = os.Chmod(key, 0o600)

	pubBytes, _ := os.ReadFile(pubFile)
	pub := strings.TrimRight(string(pubBytes), "\n")
	derived, err := cmd.Output("ssh-keygen", "-y", "-f", key)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FAIL: decrypted %s is not a valid OpenSSH private key\n", ageFile)
		return exitError
	}
	if pub == derived {
		fmt.Printf("PASS: %s.ed25519.pub matches the key inside %s.ed25519.age\n", sc, sc)
		return exitOK
	}
	fmt.Fprintf(os.Stderr, "FAIL: %s.ed25519.pub does not match the key inside %s.ed25519.age\n", sc, sc)
	fmt.Fprintf(os.Stderr, "  committed: %s\n", pub)
	fmt.Fprintf(os.Stderr, "  derived:   %s\n", derived)
	return exitError
}
