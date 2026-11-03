package repo

import "testing"

func TestWorktreePaths(t *testing.T) {
	worktree := Worktree{Root: "/repo"}
	if got := worktree.Abs("mod/default.nix"); got != "/repo/mod/default.nix" {
		t.Fatalf("Abs = %q", got)
	}

	if got, ok := worktree.Relative("/repo/mod/default.nix"); !ok || got != "mod/default.nix" {
		t.Fatalf("Relative = %q, %v", got, ok)
	}

	if _, ok := worktree.Relative("mod/default.nix"); ok {
		t.Fatal("Relative accepted non-absolute path")
	}

	if _, ok := worktree.Relative("/elsewhere/mod/default.nix"); ok {
		t.Fatal("Relative accepted path outside root")
	}
}

func TestWorktreeUnder(t *testing.T) {
	worktree := Worktree{Root: "/repo"}
	if !worktree.Under("mod/private.nix", "mod") {
		t.Fatal("expected file under module")
	}

	if worktree.Under("other/private.nix", "mod") {
		t.Fatal("unexpected file under module")
	}

	if !worktree.Under("mod", "mod") {
		t.Fatal("expected directory under itself")
	}
}
