package system

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"angst/internal/scope"
	"angst/internal/shared"
)

func usageAppSecret() {
	fmt.Print(`Usage:
  angst provision-app-secret --secrets-dir DIR --slug NAME [--slug NAME ...]
                             [--scopes work[,personal]] [--home DIR]
`)
}

// ProvisionAppSecret decrypts app-level secrets from the unified scope store
// and writes each to ~/.secrets/<slug> with mode 0600.
func ProvisionAppSecret(args []string) int {
	homeDir := ""
	secretsDir := ""
	scopesFlag := ""
	var slugs []string
	for i := 0; i < len(args); i++ {
		switch args[i] {
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
		case "--scopes":
			if i+1 < len(args) {
				scopesFlag = args[i+1]
				i++
			}
		case "--slug":
			if i+1 < len(args) {
				slugs = append(slugs, args[i+1])
				i++
			}
		case "-h", "--help":
			usageAppSecret()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown provision-app-secret option: %s\n", args[i])
			usageAppSecret()
			return shared.ExitUsage
		}
	}

	if homeDir == "" {
		homeDir = shared.Home()
	}
	if secretsDir == "" {
		fmt.Fprintln(os.Stderr, "error: --secrets-dir is required")
		return shared.ExitUsage
	}
	if len(slugs) == 0 {
		fmt.Fprintln(os.Stderr, "error: at least one --slug is required")
		return shared.ExitUsage
	}

	requested := scope.Split(scopesFlag)
	if len(requested) == 0 {
		requested = []scope.Scope{scope.Personal, scope.Work}
	}

	secretsHome := filepath.Join(homeDir, ".secrets")
	if err := os.MkdirAll(secretsHome, 0o700); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not create %s: %v\n", secretsHome, err)
		return shared.ExitError
	}

	overall := shared.ExitOK
	for _, slug := range slugs {
		if err := provisionSlug(slug, requested, secretsDir, secretsHome); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not provision '%s': %v\n", slug, err)
			overall = shared.ExitError
		}
	}
	return overall
}

func provisionSlug(slug string, scopes []scope.Scope, secretsDir, secretsHome string) error {
	var lastErr error
	for _, sc := range scopes {
		ageFile := filepath.Join(secretsDir, string(sc), slug+".age")
		if _, err := os.Stat(ageFile); err != nil {
			continue
		}
		keyFile := scope.AgeKeyfile(sc, scope.EnvOverride)
		if _, err := os.Stat(keyFile); err != nil {
			lastErr = fmt.Errorf("scope %s age key missing at %s", sc, keyFile)
			continue
		}
		tmp := filepath.Join(secretsHome, "."+slug+".tmp")
		_ = os.Remove(tmp)
		if err := shared.AgeDecrypt(keyFile, ageFile, tmp); err != nil {
			lastErr = fmt.Errorf("decrypting %s with the %s age key failed", ageFile, sc)
			_ = os.Remove(tmp)
			continue
		}
		_ = os.Chmod(tmp, 0o600)
		dest := filepath.Join(secretsHome, slug)
		if err := os.Rename(tmp, dest); err != nil {
			_ = os.Remove(tmp)
			return fmt.Errorf("installing %s failed: %w", dest, err)
		}
		_ = os.Chmod(dest, 0o600)
		fmt.Printf("provisioned app secret '%s' -> %s (scope %s)\n", slug, dest, sc)
		return nil
	}
	if lastErr != nil {
		return lastErr
	}
	return fmt.Errorf("no encrypted secret found under scopes %s", strings.Join(scopesStr(scopes), ","))
}

func scopesStr(scopes []scope.Scope) []string {
	out := make([]string, 0, len(scopes))
	for _, s := range scopes {
		out = append(out, string(s))
	}
	return out
}
