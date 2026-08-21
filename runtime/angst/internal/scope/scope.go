package scope

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"angst/internal/shared"
)

type Scope string

const (
	Personal Scope = "personal"
	Work     Scope = "work"
)

func Valid(s string) bool {
	return Scope(s) == Personal || Scope(s) == Work
}

func Split(s string) []Scope {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]Scope, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		switch Scope(p) {
		case Personal, Work:
			out = append(out, Scope(p))
		}
	}
	return out
}

func home() string {
	return shared.Home()
}

type RespectSopsEnv bool

const (
	EnvOverride RespectSopsEnv = true
	Fixed       RespectSopsEnv = false
)

func AgeKeyfile(s Scope, env RespectSopsEnv) string {
	switch s {
	case Work:
		if env && os.Getenv("SOPS_WORK_AGE_KEY_FILE") != "" {
			return os.Getenv("SOPS_WORK_AGE_KEY_FILE")
		}
		return filepath.Join(home(), ".config", "sops", "age", "work-keys.txt")
	default:
		if env && os.Getenv("SOPS_AGE_KEY_FILE") != "" {
			return os.Getenv("SOPS_AGE_KEY_FILE")
		}
		return filepath.Join(home(), ".config", "sops", "age", "keys.txt")
	}
}

func SSHKeyfile(s Scope) string {
	switch s {
	case Work:
		if k := os.Getenv("ANGST_WORK_SSH_KEY"); k != "" {
			return k
		}
		return filepath.Join(home(), ".ssh", "work_ed25519")
	default:
		if k := os.Getenv("ANGST_SSH_KEY"); k != "" {
			return k
		}
		return filepath.Join(home(), ".ssh", "id_ed25519")
	}
}

func Recipient(keyfile string) (string, error) {
	if _, err := os.Stat(keyfile); err != nil {
		return "", &MissingKeyfileError{keyfile}
	}
	out, err := exec.Command("age-keygen", "-y", keyfile).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimRight(string(out), "\n"), nil
}

func RecipientFor(s Scope, env RespectSopsEnv) (string, error) {
	return Recipient(AgeKeyfile(s, env))
}

type MissingKeyfileError struct{ Path string }

func (e *MissingKeyfileError) Error() string { return "no age key at " + e.Path }
