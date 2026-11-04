package scan

import (
	"testing"

	"github.com/joaosimsic/angst/infra/golib/repo"
)

func hasKey(values map[string]struct{}, key string) bool {
	_, ok := values[key]

	return ok
}

func TestScan(t *testing.T) {
	worktree := repo.Worktree{Root: "/tmp/repo"}

	files := map[string]struct{}{
		"mod/default.nix": {},
		"mod/private.nix": {},
	}

	parsedExpression := `(let mod = (import /tmp/repo/mod/default.nix); in { a = (mod).one; b = (mod).two; inherit (mod) three four; c = ((import /tmp/repo/mod/private.nix)).five; d = (import /tmp/repo/mod/default.nix).six; e = mod.seven; })`

	result, err := (Scanner{Worktree: worktree, Files: files}).Scan(parsedExpression)
	if err != nil {
		t.Fatalf("scan: %v", err)
	}
	if len(result.Issues) != 0 {
		t.Fatalf("unexpected issues: %v", result.Issues)
	}

	if !hasKey(result.Imports, "mod/default.nix") || !hasKey(result.Imports, "mod/private.nix") {
		t.Fatalf("missing imports: %#v", result.Imports)
	}

	if result.Aliases["mod"] != "mod/default.nix" {
		t.Fatalf("wrong alias: %#v", result.Aliases)
	}

	for _, name := range []string{"one", "two", "three", "four", "six", "seven"} {
		if !hasKey(result.Refs["mod/default.nix"], name) {
			t.Fatalf("missing ref %s: %#v", name, result.Refs)
		}
	}

	if !hasKey(result.Refs["mod/private.nix"], "five") {
		t.Fatalf("missing direct ref: %#v", result.Refs)
	}
}

func TestScanDynamicImport(t *testing.T) {
	result, err := (Scanner{Worktree: repo.Worktree{Root: "/tmp/repo"}}).Scan(`(let x = "mod"; in (import x))`)
	if err != nil {
		t.Fatalf("scan: %v", err)
	}
	if len(result.Issues) != 1 {
		t.Fatalf("expected one issue, got %#v", result.Issues)
	}
}

func TestScanInheritImportForms(t *testing.T) {
	worktree := repo.Worktree{Root: "/tmp/repo"}

	files := map[string]struct{}{
		"mod/default.nix": {},
	}

	testCases := []struct {
		name             string
		parsedExpression string
		members          []string
	}{
		{"direct", `inherit (import /tmp/repo/mod/default.nix) one two;`, []string{"one", "two"}},
		{"parenthesized", `inherit ((import /tmp/repo/mod/default.nix)) three four;`, []string{"three", "four"}},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			result, err := (Scanner{Worktree: worktree, Files: files}).Scan(testCase.parsedExpression)
			if err != nil {
				t.Fatalf("scan: %v", err)
			}

			for _, member := range testCase.members {
				if !hasKey(result.Refs["mod/default.nix"], member) {
					t.Fatalf("missing ref %s: %#v", member, result.Refs)
				}
			}
		})
	}
}

func TestScanIgnoresAliasOutsideWorktree(t *testing.T) {
	result, err := (Scanner{Worktree: repo.Worktree{Root: "/tmp/repo"}}).Scan(`let outside = (import /tmp/other/file.nix); in outside`)
	if err != nil {
		t.Fatalf("scan: %v", err)
	}
	if _, ok := result.Aliases["outside"]; ok {
		t.Fatalf("unexpected alias: %#v", result.Aliases)
	}
}
