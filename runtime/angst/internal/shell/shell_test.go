package shell

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPrepareShellPrependsPathAndSetsEnv(t *testing.T) {
	// isolate HOME so tree-sitter symlink lands in a temp dir
	tmp := t.TempDir()
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tmp)
	defer os.Setenv("HOME", oldHome)

	devBin := t.TempDir()
	fakeShell := filepath.Join(devBin, "fake-bash")
	if err := os.WriteFile(fakeShell, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	parsers := t.TempDir()
	queries := t.TempDir()

	os.Setenv("SHELL_DEV_PATH", devBin)
	os.Setenv("SHELL_SAFE_PATH", devBin)
	os.Setenv("SHELL_ENABLED_SHELLS", fakeShell)
	os.Setenv("SHELL_TS_PARSERS", parsers)
	os.Setenv("SHELL_TS_QUERIES", queries)
	os.Setenv("PATH", "/usr/bin:/bin")
	defer os.Unsetenv("SHELL_DEV_PATH")
	defer os.Unsetenv("SHELL_SAFE_PATH")
	defer os.Unsetenv("SHELL_ENABLED_SHELLS")
	defer os.Unsetenv("SHELL_TS_PARSERS")
	defer os.Unsetenv("SHELL_TS_QUERIES")

	cmd, env, err := prepareShell("dev")
	if err != nil {
		t.Fatal(err)
	}
	if cmd != fakeShell {
		t.Fatalf("expected cmd %q, got %q", fakeShell, cmd)
	}

	envMap := map[string]string{}
	for _, e := range env {
		if k, v, ok := splitEnv(e); ok {
			envMap[k] = v
		}
	}
	if got := envMap["PATH"]; got != devBin+":/usr/bin:/bin" {
		t.Fatalf("PATH not prepended correctly: %q", got)
	}
	if envMap["IN_NIX_SHELL"] != "dev" {
		t.Fatalf("IN_NIX_SHELL=%q", envMap["IN_NIX_SHELL"])
	}
	if envMap["name"] != "dev" || envMap["SHELL_MODE"] != "dev" {
		t.Fatalf("name/SHELL_MODE wrong: %q %q", envMap["name"], envMap["SHELL_MODE"])
	}
	if envMap["ORIGINAL_SHELL"] != fakeShell {
		t.Fatalf("ORIGINAL_SHELL=%q", envMap["ORIGINAL_SHELL"])
	}

	// tree-sitter symlinks created
	parserLink := filepath.Join(tmp, ".local", "share", "tree-sitter", "parser")
	if link, err := os.Readlink(parserLink); err != nil || link != parsers {
		t.Fatalf("parser symlink wrong: %q err %v", link, err)
	}
	queriesLink := filepath.Join(tmp, ".local", "share", "tree-sitter", "queries")
	if link, err := os.Readlink(queriesLink); err != nil || link != queries {
		t.Fatalf("queries symlink wrong: %q err %v", link, err)
	}
}

func TestPrepareShellMissingPathErrors(t *testing.T) {
	os.Unsetenv("SHELL_DEV_PATH")
	os.Unsetenv("SHELL_SAFE_PATH")
	if _, _, err := prepareShell("dev"); err == nil {
		t.Fatal("expected error when SHELL_DEV_PATH unset")
	}
}

func splitEnv(e string) (string, string, bool) {
	for i := 0; i < len(e); i++ {
		if e[i] == '=' {
			return e[:i], e[i+1:], true
		}
	}
	return "", "", false
}
