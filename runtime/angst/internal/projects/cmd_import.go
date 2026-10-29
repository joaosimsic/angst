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
	scopesFlag := ""
	scopesSet := false
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--all":
			all = true
		case "--scopes":
			scopesSet = true
			if i+1 < len(args) {
				scopesFlag = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return shared.ExitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown import option: %s\n", args[i])
			usage()
			return shared.ExitUsage
		}
	}
	_ = all
	selectedScopes := scopesFor(scopesFlag, scopesSet)
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

	for _, s := range selectedScopes {
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
