package projects

import (
	"fmt"
	"os"
	"path/filepath"

	"angst/internal/scope"
	"angst/internal/shared"
	"angst/internal/vault"
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
	_ = all
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
		tarball := filepath.Join(repo, string(s)+".tar.age")
		if _, err := os.Stat(tarball); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s tarball at %s; skipping\n", s, tarball)
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s import\n", s, s)
			continue
		}
		dest := filepath.Join(store, string(s))
		if err := vault.DecryptTarball(keyfile, tarball, dest); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s tarball; skipping\n", s)
			continue
		}
		fmt.Printf("imported %s\n", s)
	}
	return shared.ExitOK
}
