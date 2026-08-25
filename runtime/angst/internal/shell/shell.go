package shell

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"angst/internal/shared"
)

func usage() {
	fmt.Print(`Usage:
  angst shell dev
  angst shell safe
`)
}

// Run dispatches `angst shell dev|safe`.
func Run(args []string) int {
	mode := ""
	if len(args) > 0 {
		mode = args[0]
	}
	switch mode {
	case "dev", "safe":
		if err := enter(mode); err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to enter %s shell: %v\n", mode, err)
			return shared.ExitError
		}
		return shared.ExitOK
	case "", "-h", "--help":
		usage()
		return shared.ExitOK
	default:
		fmt.Fprintf(os.Stderr, "unknown shell mode: %s\n", mode)
		usage()
		return shared.ExitUsage
	}
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func removeIfExists(path string) {
	if fi, err := os.Lstat(path); err == nil {
		if fi.IsDir() {
			_ = os.RemoveAll(path)
		} else {
			_ = os.Remove(path)
		}
	}
}

func setupTreesitter() error {
	home, _ := os.UserHomeDir()
	if home == "" {
		home = os.Getenv("HOME")
	}
	tsDir := filepath.Join(home, ".local", "share", "tree-sitter")

	parsers := os.Getenv("SHELL_TS_PARSERS")
	queries := os.Getenv("SHELL_TS_QUERIES")
	if parsers == "" && queries == "" {
		return nil
	}

	if err := os.MkdirAll(tsDir, 0o755); err != nil {
		return err
	}
	if parsers != "" {
		link := filepath.Join(tsDir, "parser")
		removeIfExists(link)
		if err := os.Symlink(parsers, link); err != nil {
			return err
		}
	}
	if queries != "" {
		link := filepath.Join(tsDir, "queries")
		removeIfExists(link)
		if err := os.Symlink(queries, link); err != nil {
			return err
		}
	}
	return nil
}

func resolveHostShell() string {
	if v := os.Getenv("SHELL_ENABLED_SHELLS"); v != "" {
		for _, p := range strings.Split(v, ":") {
			if p != "" && fileExists(p) {
				return p
			}
		}
	}
	if s := os.Getenv("SHELL"); s != "" {
		return s
	}
	return "/bin/bash"
}

// prepareShell performs all of the shell-switch setup (env read, PATH prepend,
// tree-sitter symlink) and returns the command to exec plus the augmented
// environment. It is separated from enter so it can be unit-tested without
// replacing the test process.
func prepareShell(mode string) (cmdPath string, env []string, err error) {
	var pathKey string
	switch mode {
	case "dev":
		pathKey = "SHELL_DEV_PATH"
	case "safe":
		pathKey = "SHELL_SAFE_PATH"
	default:
		return "", nil, fmt.Errorf("unknown shell mode: %s", mode)
	}

	extraPath := os.Getenv(pathKey)
	if extraPath == "" {
		return "", nil, fmt.Errorf("%s not set — was this binary built by Nix?", pathKey)
	}

	if err := setupTreesitter(); err != nil {
		return "", nil, err
	}

	current := os.Getenv("PATH")
	newPath := extraPath + ":" + current

	shell := resolveHostShell()
	cmd := shell
	if mode == "dev" {
		if entry := os.Getenv("SHELL_DEV_ENTRY"); entry != "" {
			cmd = entry
		}
	}

	env = append(os.Environ(),
		"PATH="+newPath,
		"IN_NIX_SHELL="+mode,
		"name="+mode,
		"SHELL_MODE="+mode,
		"ORIGINAL_SHELL="+shell,
	)
	return cmd, env, nil
}

func enter(mode string) error {
	cmd, env, err := prepareShell(mode)
	if err != nil {
		return err
	}
	return syscall.Exec(cmd, []string{cmd}, env)
}
