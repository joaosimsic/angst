package db

import (
	"fmt"
	"os"
	"path/filepath"

	"angst/internal/scope"
	"angst/internal/shared"
	"angst/internal/vault"
)

func cmdImport(args []string) int {
	for _, a := range args {
		switch a {
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown import option: %s\n", a)
			usage()
			return shared.ExitUsage
		}
	}
	repo := repoRoot()
	store := storeRoot()
	if err := os.MkdirAll(store, 0o700); err != nil {
		fmt.Fprintf(os.Stderr, "warn: could not create db store at %s: %v\n", store, err)
		return shared.ExitOK
	}
	_ = os.Chmod(store, 0o700)

	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		tarball := filepath.Join(repo, string(s)+".tar.age")
		if _, err := os.Stat(tarball); err != nil {
			// not an error, just no store for this scope
			continue
		}
		keyfile := scope.AgeKeyfile(s, scope.EnvOverride)
		if _, err := os.Stat(keyfile); err != nil {
			fmt.Fprintf(os.Stderr, "warn: no %s age key; skipping %s db import\n", s, s)
			continue
		}
		dest := filepath.Join(store, string(s))
		if err := vault.DecryptTarball(keyfile, tarball, dest); err != nil {
			fmt.Fprintf(os.Stderr, "warn: could not decrypt %s db tarball; skipping: %v\n", s, err)
			continue
		}
		fmt.Printf("imported db %s\n", s)
	}
	return shared.ExitOK
}
