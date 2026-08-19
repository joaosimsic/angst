package projects

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"

	"angst/internal/shared"
	"angst/internal/scope"
)

func cmdImport(args []string) int {
	all := false
	for _, a := range args {
		switch a {
		case "--all":
			all = true
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown import option: %s\n", a)
			usage()
			return shared.ExitUsage
		}
	}

	store := storeRoot()
	repo := repoRoot()
	if _, err := os.Stat(repo); err != nil {
		fmt.Fprintf(os.Stderr, "warn: repo store not found at %s; nothing to import\n", repo)
		return shared.ExitOK
	}
	if err := os.MkdirAll(store, 0o700); err != nil {
		return shared.ExitOK
	}
	_ = os.Chmod(store, 0o700)
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(repo, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s import\n", s, s)
			continue
		}
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			if !all && !selected(id) {
				continue
			}
			if _, err := os.Stat(filepath.Join(store, string(s), id, "metadata.yaml")); err == nil {
				continue
			}
			importOne(s, id)
		}
	}
	return shared.ExitOK
}

func importOne(s scope.Scope, id string) {
	store := storeRoot()
	repo := repoRoot()
	meta := filepath.Join(repo, string(s), id, "metadata.yaml")
	if _, err := os.Stat(meta); err != nil {
		return
	}
	dir := filepath.Join(store, string(s), id)
	_ = os.MkdirAll(dir, 0o700)

	data, err := sopsDecrypt(s, meta)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not decrypt %s/%s metadata; skipping\n", s, id)
		return
	}
	plain := bytes.TrimRight(data, "\n")
	_ = os.WriteFile(filepath.Join(dir, "metadata.yaml"), append(plain, '\n'), 0o600)
	_ = os.Chmod(filepath.Join(dir, "metadata.yaml"), 0o600)

	envSrc := filepath.Join(repo, string(s), id, "env")
	if _, err := os.Stat(envSrc); err == nil {
		if err := sopsDecryptToFile(s, envSrc, filepath.Join(dir, "env")); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s/%s env; skipping\n", s, id)
		} else {
			_ = os.Chmod(filepath.Join(dir, "env"), 0o600)
		}
	} else {
		_ = os.WriteFile(filepath.Join(dir, "env"), nil, 0o600)
		_ = os.Chmod(filepath.Join(dir, "env"), 0o600)
	}
	fmt.Printf("imported %s/%s\n", s, id)
}

func cmdExport(args []string) int {
	all := false
	for _, a := range args {
		switch a {
		case "--all":
			all = true
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown export option: %s\n", a)
			usage()
			return shared.ExitUsage
		}
	}

	store := storeRoot()
	repo := repoRoot()
	if _, err := os.Stat(store); err != nil {
		fmt.Fprintf(os.Stderr, "warn: working store not found at %s; nothing to export\n", store)
		return shared.ExitOK
	}
	_ = os.MkdirAll(repo, 0o700)

	failed := false
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		scopePath := filepath.Join(store, string(s))
		if st, err := os.Stat(scopePath); err != nil || !st.IsDir() {
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s export\n", s, s)
			continue
		}
		metas, _ := filepath.Glob(filepath.Join(scopePath, "*", "metadata.yaml"))
		for _, meta := range metas {
			id := filepath.Base(filepath.Dir(meta))
			if !all && !selected(id) {
				continue
			}
			target := filepath.Join(repo, string(s), id)
			_ = os.MkdirAll(target, 0o700)
			if encrypt(s, meta, filepath.Join(target, "metadata.yaml")) != nil ||
				encrypt(s, filepath.Join(store, string(s), id, "env"), filepath.Join(target, "env")) != nil {
				fmt.Fprintf(os.Stderr, "error: encryption failed for %s/%s\n", s, id)
				failed = true
				continue
			}
			fmt.Printf("exported %s/%s\n", s, id)
		}
	}
	fmt.Printf("==> Exported to %s (remember to commit).\n", repo)
	if failed {
		return shared.ExitError
	}
	return shared.ExitOK
}
