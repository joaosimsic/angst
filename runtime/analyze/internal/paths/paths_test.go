package paths

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestFindHostConfigDir(t *testing.T) {
	repo := t.TempDir()

	dir := filepath.Join(repo, "hosts", "personal", "nixos")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "default.nix"), []byte("{}\n"), 0o644)
	os.MkdirAll(filepath.Join(repo, "hosts", "ci"), 0o755)

	if got, ok := FindHostConfigDir(repo, "nixos"); !ok || got != dir {
		t.Fatalf("FindHostConfigDir(nixos) = %q,%v", got, ok)
	}
	if _, ok := FindHostConfigDir(repo, "missing"); ok {
		t.Fatal("expected missing host dir")
	}

	flat := filepath.Join(repo, "hosts", "flat")
	os.MkdirAll(flat, 0o755)
	os.WriteFile(filepath.Join(flat, "default.nix"), []byte("{}\n"), 0o644)
	if got, ok := FindHostConfigDir(repo, "flat"); !ok || got != flat {
		t.Fatalf("flat lookup = %q,%v", got, ok)
	}
}

func TestRepoRootPriority(t *testing.T) {
	old := os.Getenv("ANGST_REPO_ROOT")
	defer func() {
		if old != "" {
			os.Setenv("ANGST_REPO_ROOT", old)
		} else {
			os.Unsetenv("ANGST_REPO_ROOT")
		}
	}()

	if runtime.GOOS != "linux" {
		t.Skip("git discovery relies on POSIX git")
	}

	os.Setenv("ANGST_REPO_ROOT", "/explicit/root")
	if got := RepoRoot(); got != "/explicit/root" {
		t.Fatalf("env override = %q", got)
	}
	os.Unsetenv("ANGST_REPO_ROOT")

	want, err := gitTopLevel()
	if err != nil {
		t.Skipf("not inside a git checkout: %v", err)
	}
	if got := RepoRoot(); got != want {
		t.Fatalf("git discovery = %q, want %q", got, want)
	}
}

func gitTopLevel() (string, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	return strings.TrimSpace(string(out)), err
}

func TestSubDir(t *testing.T) {
	cases := []struct {
		p    string
		n    int
		want string
	}{
		{"a/b/c/d/e", 4, "a/b/c/d"},
		{"a/b", 4, "a/b"},
		{"a/b/c/d/e/f", 4, "a/b/c/d"},
	}
	for _, c := range cases {
		if got := SubDir(c.p, c.n); got != c.want {
			t.Fatalf("SubDir(%q,%d) = %q, want %q", c.p, c.n, got, c.want)
		}
	}
}

func TestLinesPreservesInternalBlanks(t *testing.T) {
	if got := Lines("a\n\nb\n"); len(got) != 3 || got[0] != "a" || got[1] != "" || got[2] != "b" {
		t.Fatalf("Lines = %#v", got)
	}
	if got := Lines("\n\n"); got != nil {
		t.Fatalf("Lines(blank) = %#v", got)
	}
}

func TestUniqueSortedAndJoin(t *testing.T) {
	a := Lines("z\nb\na\n")
	b := Lines("a\ny\n")
	got := UniqueSorted(a, b)
	want := []string{"a", "b", "y", "z"}
	if len(got) != len(want) {
		t.Fatalf("UniqueSorted = %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("UniqueSorted = %v", got)
		}
	}
	if out := string(JoinLines([]string{"a", "b"})); out != "a\nb\n" {
		t.Fatalf("JoinLines = %q", out)
	}
}
