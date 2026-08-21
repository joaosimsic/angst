package system

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"

	"angst/internal/cmd"
	"angst/internal/scope"
	"angst/internal/shared"
)

func ProvisionSSHKey(args []string) int {
	username := ""
	homeDir := ""
	secretsDir := ""
	scopesFlag := ""
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
		case "--scopes":
			if i+1 < len(args) {
				scopesFlag = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown provision-ssh-key option: %s\n", args[i])
			return shared.ExitUsage
		}
	}

	_ = syscall.Umask(0o077)
	sshDir := filepath.Join(homeDir, ".ssh")
	tmp, err := os.MkdirTemp("", "angst-sshprov-")
	if err != nil {
		return shared.ExitError
	}
	defer os.RemoveAll(tmp)

	provision := func(scope, ageKey, dest string) int {
		ageFile := filepath.Join(secretsDir, scope+".ed25519.age")
		if _, err := os.Stat(ageKey); err != nil {
			return shared.ExitOK
		}
		if _, err := os.Stat(ageFile); err != nil {
			return shared.ExitOK
		}
		plain := filepath.Join(tmp, scope+".key")
		if err := shared.AgeDecrypt(ageKey, ageFile, plain); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s; skipping %s SSH key\n", ageFile, scope)
			return shared.ExitOK
		}
		_ = os.Chmod(plain, 0o600)

		pub, err := cmd.Output("ssh-keygen", "-y", "-f", plain)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warn: decrypted %s key is invalid; leaving existing %s untouched\n", scope, dest)
			return shared.ExitOK
		}
		pubPath := filepath.Join(tmp, scope+".pub")
		_ = os.WriteFile(pubPath, []byte(pub+"\n"), 0o600)

		tmpInstall := filepath.Join(sshDir, dest+".tmp")
		tmpPub := filepath.Join(sshDir, dest+".pub.tmp")
		root := os.Geteuid() == 0
		if root {
			if err := cmd.Run("install", "-d", "-m", "700", "-o", username, "-g", "users", sshDir); err != nil {
				return shared.ExitError
			}
			if err := cmd.Run("install", "-m", "600", "-o", username, "-g", "users", plain, tmpInstall); err != nil {
				return shared.ExitError
			}
			if err := cmd.Run("install", "-m", "644", "-o", username, "-g", "users", pubPath, tmpPub); err != nil {
				return shared.ExitError
			}
		} else {
			if err := cmd.Run("install", "-d", "-m", "700", sshDir); err != nil {
				return shared.ExitError
			}
			if err := cmd.Run("install", "-m", "600", plain, tmpInstall); err != nil {
				return shared.ExitError
			}
			if err := cmd.Run("install", "-m", "644", pubPath, tmpPub); err != nil {
				return shared.ExitError
			}
		}
		_ = os.Rename(tmpInstall, filepath.Join(sshDir, dest))
		_ = os.Rename(tmpPub, filepath.Join(sshDir, dest+".pub"))
		_ = os.Remove(plain)
		fmt.Printf("provisioned %s SSH key -> %s/%s\n", scope, sshDir, dest)
		return shared.ExitOK
	}

	scopeTargets := map[scope.Scope]struct {
		ageKey string
		dest   string
	}{
		scope.Personal: {
			ageKey: filepath.Join(homeDir, ".config", "sops", "age", "keys.txt"),
			dest:   "id_ed25519",
		},
		scope.Work: {
			ageKey: filepath.Join(homeDir, ".config", "sops", "age", "work-keys.txt"),
			dest:   "work_ed25519",
		},
	}

	requested := scope.Split(scopesFlag)
	if len(requested) == 0 {
		requested = []scope.Scope{scope.Personal, scope.Work}
	}

	for _, sc := range requested {
		t, ok := scopeTargets[sc]
		if !ok {
			continue
		}
		code := provision(string(sc), t.ageKey, t.dest)
		if code != shared.ExitOK {
			return code
		}
	}
	return shared.ExitOK
}
