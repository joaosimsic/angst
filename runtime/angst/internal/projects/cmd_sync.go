package projects

import (
	"fmt"
	"os"
	"path/filepath"

	"angst/internal/scope"
	"angst/internal/shared"
)

func cmdSync(args []string) int {
	_ = args
	store := storeRoot()
	root := projectsRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "warn: projects store not found at %s; nothing to sync\n", store)
		return shared.ExitOK
	}
	if err := os.MkdirAll(root, 0o755); err != nil {
		return shared.ExitError
	}
	_ = os.Chmod(root, 0o755)

	failed := false
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(store, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		gitSSH := "ssh -o StrictHostKeyChecking=accept-new -i " + scope.SSHKeyfile(s)
		metas := findMetadata(scopePath)
		for _, meta := range metas {
			rel, err := filepath.Rel(scopePath, filepath.Dir(meta))
			if err != nil {
				continue
			}
			id := rel
			if !selected(id) {
				continue
			}
			m, err := readMetadata(meta)
			if err != nil {
				continue
			}
			if m.Name == "" {
				fmt.Fprintf(os.Stderr, "warn: empty name in %s/%s metadata; skipping\n", s, id)
				continue
			}
			target := filepath.Join(root, m.Name)
			if _, err := os.Stat(filepath.Join(target, ".git")); err != nil {
				fmt.Printf("cloning %s -> %s\n", m.Repo, target)
				if err := clone(gitSSH, m.Repo, target); err != nil {
					fmt.Fprintf(os.Stderr, "warn: clone failed for '%s'; skipping (network down?)\n", m.Name)
					continue
				}
			}
			if err := syncEnv(s, id, m.Name); err != nil {
				failed = true
			}
		}
	}
	if failed {
		return shared.ExitError
	}
	return shared.ExitOK
}

func findMetadata(scopePath string) []string {
	var out []string
	_ = filepath.WalkDir(scopePath, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if d.Name() != "metadata.json" {
			return nil
		}
		rel, rerr := filepath.Rel(scopePath, filepath.Dir(path))
		if rerr != nil || rel == "." {
			return nil
		}
		out = append(out, path)
		return nil
	})
	return out
}

func syncEnv(s scope.Scope, id, name string) error {
	store := storeRoot()
	envFile := filepath.Join(store, string(s), id, ".env")
	target := filepath.Join(projectsRoot(), name, ".env")
	sd := sidecarDir()
	sidecar := filepath.Join(sd, name+".env.sha256")
	_ = os.MkdirAll(sd, 0o700)
	_ = os.Chmod(sd, 0o700)

	if _, err := os.Stat(envFile); err != nil {
		fmt.Fprintf(os.Stderr, "warn: no env in store for %s; skipping\n", name)
		return nil
	}
	storeHash := sha256hex(envFile)

	if _, err := os.Stat(target); err != nil {
		if err := copyChmod(envFile, target, 0o600); err != nil {
			return err
		}
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		fmt.Printf("materialized %s/.env\n", name)
		return nil
	}

	cur := sha256hex(target)
	last := readTrimmed(sidecar)

	if cur == storeHash {
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		return nil
	}
	if cur == last {
		if err := copyChmod(envFile, target, 0o600); err != nil {
			return err
		}
		_ = os.WriteFile(sidecar, []byte(storeHash+"\n"), 0o644)
		fmt.Printf("updated %s/.env (store changed)\n", name)
		return nil
	}

	fmt.Fprintf(os.Stderr, "stale: %s/.env was edited locally; not clobbering\n", name)
	envKeyDiff(envFile, target)
	return errStale
}
