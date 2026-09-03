package system

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/scope"
	"angst/internal/shared"
)

func usageProvisionVPN() {
	fmt.Print(`Usage:
  angst provision-vpn --secrets-dir DIR --dest-dir DIR [--user USER] [--home DIR] [--scopes personal[,work]]

  Decrypts age-encrypted VPN configs from secrets/vpn/<scope>/*.{ovpn,creds}.age
  into destDir. Supports both scopes (personal/work) with scope-isolated keys.

  Repo layout (age-encrypted):
    secrets/vpn/personal/<name>.ovpn.age   -> destDir/<name>.ovpn
    secrets/vpn/personal/<name>.creds.age  -> destDir/<name>.creds
    secrets/vpn/work/<name>.ovpn.age       -> destDir/<name>.ovpn
    secrets/vpn/work/<name>.creds.age      -> destDir/<name>.creds

  Each file is encrypted with its scope's recipient only (personal -> keys.txt,
  work -> work-keys.txt). Missing keys or files are skipped with a warning.
`)
}

func ProvisionVPN(args []string) int {
	secretsDir := ""
	destDir := ""
	username := ""
	homeDir := ""
	scopesFlag := ""

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--secrets-dir":
			if i+1 < len(args) {
				secretsDir = args[i+1]
				i++
			}
		case "--dest-dir":
			if i+1 < len(args) {
				destDir = args[i+1]
				i++
			}
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
		case "--scopes":
			if i+1 < len(args) {
				scopesFlag = args[i+1]
				i++
			}
		case "-h", "--help":
			usageProvisionVPN()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown provision-vpn option: %s\n", args[i])
			usageProvisionVPN()
			return shared.ExitUsage
		}
	}

	if username != "" {
		_ = os.Setenv("USER", username)
	}
	if homeDir != "" {
		_ = os.Setenv("HOME", homeDir)
	}

	if secretsDir == "" {
		fmt.Fprintln(os.Stderr, "error: --secrets-dir is required")
		return shared.ExitUsage
	}
	if destDir == "" {
		fmt.Fprintln(os.Stderr, "error: --dest-dir is required")
		return shared.ExitUsage
	}

	requested := scope.Split(scopesFlag)
	if len(requested) == 0 {
		requested = []scope.Scope{scope.Personal, scope.Work}
	}

	if err := os.MkdirAll(destDir, 0o700); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not create %s: %v\n", destDir, err)
		return shared.ExitError
	}
	_ = os.Chmod(destDir, 0o700)

	expected := map[string]struct{}{}
	overall := shared.ExitOK
	for _, sc := range requested {
		keyFile := scope.AgeKeyfile(sc, scope.EnvOverride)
		if _, err := os.Stat(keyFile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: %s age key not found at %s; skipping scope %s\n", sc, keyFile, sc)
			continue
		}
		scopeDir := filepath.Join(secretsDir, string(sc))
		if _, err := os.Stat(scopeDir); err != nil {
			continue
		}
		entries, err := os.ReadDir(scopeDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not read %s: %v\n", scopeDir, err)
			overall = shared.ExitError
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			if !strings.HasSuffix(name, ".age") {
				continue
			}
			plainName := strings.TrimSuffix(name, ".age")
			if !strings.HasSuffix(plainName, ".ovpn") && !strings.HasSuffix(plainName, ".creds") && !strings.HasSuffix(plainName, ".conf") {
				fmt.Fprintf(os.Stderr, "warn: skipping %s/%s: unexpected suffix (want .ovpn/.creds/.conf)\n", sc, name)
				continue
			}
			expected[plainName] = struct{}{}
			src := filepath.Join(scopeDir, name)
			dest := filepath.Join(destDir, plainName)
			tmp := dest + ".tmp"

			_ = os.Remove(tmp)
			if err := shared.AgeDecrypt(keyFile, src, tmp); err != nil {
				fmt.Fprintf(os.Stderr, "warn: could not decrypt %s with %s key: %v\n", src, sc, err)
				_ = os.Remove(tmp)
				overall = shared.ExitError
				continue
			}
			_ = os.Chmod(tmp, 0o600)
			if err := os.Rename(tmp, dest); err != nil {
				fmt.Fprintf(os.Stderr, "error: installing %s -> %s: %v\n", tmp, dest, err)
				_ = os.Remove(tmp)
				overall = shared.ExitError
				continue
			}
			_ = os.Chmod(dest, 0o600)
			fmt.Printf("provisioned vpn %s/%s -> %s\n", sc, name, dest)
		}
	}
	if entries, err := os.ReadDir(destDir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			n := e.Name()
			if strings.HasSuffix(n, ".tmp") {
				_ = os.Remove(filepath.Join(destDir, n))
				continue
			}
			if _, ok := expected[n]; !ok && (strings.HasSuffix(n, ".ovpn") || strings.HasSuffix(n, ".creds") || strings.HasSuffix(n, ".conf")) {
				p := filepath.Join(destDir, n)
				_ = os.Remove(p)
				fmt.Printf("removed stale vpn %s\n", p)
			}
		}
	}

	return overall
}
