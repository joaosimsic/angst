package main

import (
	"path"
	"testing"
)

func TestIsTestPath(t *testing.T) {
	cases := map[string]bool{
		"mod/test.nix":          true,
		"mod/foo.test.nix":      true,
		"mod/foo_test.nix":      true,
		"mod/tests/foo.nix":     true,
		"mod/testdata/foo.nix":  true,
		"mod/fixtures/foo.nix":  true,
		"mod/default.nix":       false,
		"mod/checks.nix":        false,
		path.Join("a", "b.nix"): false,
	}

	for file, want := range cases {
		if got := isTestPath(file); got != want {
			t.Fatalf("isTestPath(%q) = %v, want %v", file, got, want)
		}
	}
}

func TestFindModuleRoot(t *testing.T) {
	trackedFiles := map[string]struct{}{
		"mod/default.nix":          {},
		"mod/internal/default.nix": {},
	}

	if got := findModuleRoot("mod/private.nix", trackedFiles); got != "mod" {
		t.Fatalf("mod root = %q", got)
	}

	if got := findModuleRoot("mod/internal/private.nix", trackedFiles); got != "mod/internal" {
		t.Fatalf("nested root = %q", got)
	}

	if got := findModuleRoot("infra/lib/leaf.nix", trackedFiles); got != "" {
		t.Fatalf("leaf root = %q", got)
	}
}
