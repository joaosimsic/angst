package projects

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"angst/internal/scope"
	"angst/internal/vault"
)

func TestKeys(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "env")
	content := "FOO=bar\nBAZ=qux\nFOO=dup\n# comment\n\nINVALID KEY=nope\nNOPE_WITHOUT_EQ\n_UNDER=1\nALSO9=2\n"
	if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	got := keys(p)
	want := []string{"ALSO9", "BAZ", "FOO", "_UNDER"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("keys() = %v, want %v", got, want)
	}
}

func TestSelected(t *testing.T) {
	cases := []struct {
		name   string
		set    bool
		val    string
		id     string
		expect bool
	}{
		{"unset means all", false, "", "any", true},
		{"set-with-empty means none", true, "", "any", false},
		{"matching id", true, "abc def", "def", true},
		{"non-matching id", true, "abc def", "ghi", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if c.set {
				os.Setenv("ANGST_PROJECTS_ONLY", c.val)
			} else {
				os.Unsetenv("ANGST_PROJECTS_ONLY")
			}
			if got := selected(c.id); got != c.expect {
				t.Fatalf("selected(%q) = %v, want %v", c.id, got, c.expect)
			}
		})
	}
	os.Unsetenv("ANGST_PROJECTS_ONLY")
}

func TestSyncEnvStaleTransitions(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("ANGST_PROJECTS_ROOT", filepath.Join(home, "proj"))
	store := filepath.Join(home, "store")
	t.Setenv("ANGST_PROJECTS_STORE", store)

	envFile := filepath.Join(store, "personal", "id1", "env")
	os.MkdirAll(filepath.Dir(envFile), 0o700)
	os.WriteFile(envFile, []byte("A=one\nB=two\n"), 0o600)
	name := "stale-test"
	clone := filepath.Join(filepath.Join(home, "proj"), name)
	os.MkdirAll(clone, 0o755)
	os.MkdirAll(filepath.Join(clone, ".git"), 0o755)

	if err := syncEnv("personal", "id1", name); err != nil {
		t.Fatalf("initial materialize failed: %v", err)
	}
	target := filepath.Join(clone, ".env")
	if perm := permOf(t, target); perm != 0o600 {
		t.Fatalf("materialized .env perm = %#o, want 600", perm)
	}

	os.WriteFile(envFile, []byte("A=one\nB=two\nC=three\n"), 0o600)
	if err := syncEnv("personal", "id1", name); err != nil {
		t.Fatalf("store-change update failed: %v", err)
	}
	if !contains(t, target, "C=three") {
		t.Fatal("store change not materialized")
	}

	os.WriteFile(target, []byte("A=local\n"), 0o600)
	err := syncEnv("personal", "id1", name)
	if err == nil {
		t.Fatal("expected stale error")
	}
	if !contains(t, target, "A=local") {
		t.Fatal("local edit was clobbered")
	}
	sidecar := filepath.Join(home, ".secrets", "projects", name+".env.sha256")
	if got := readTrimmed(sidecar); got != sha256hex(envFile) {
		t.Fatalf("sidecar held %q, want store hash", got)
	}
}

// TestVaultImportSyncRoundTrip seeds a synthetic working store, encrypts each
// scope with `vault encrypt --dir`, imports the tarballs back, and asserts a
// byte-exact round trip plus `.env` materialization on sync. Skips when the
// real `age` / `age-keygen` binaries are not on PATH.
func TestVaultImportSyncRoundTrip(t *testing.T) {
	for _, bin := range []string{"age", "age-keygen"} {
		if _, err := exec.LookPath(bin); err != nil {
			t.Skipf("%s not on PATH; skipping vault import/sync round-trip", bin)
		}
	}

	home := t.TempDir()
	t.Setenv("HOME", home)
	store := filepath.Join(home, "store")
	repo := filepath.Join(home, "repo")
	root := filepath.Join(home, "root")
	os.MkdirAll(filepath.Join(home, ".config", "sops", "age"), 0o700)
	ageKey := filepath.Join(home, ".config", "sops", "age", "keys.txt")
	workKey := filepath.Join(home, ".config", "sops", "age", "work-keys.txt")
	for _, kf := range []string{ageKey, workKey} {
		if out, err := exec.Command("age-keygen", "-o", kf).CombinedOutput(); err != nil {
			t.Fatalf("age-keygen %s: %v (%s)", kf, err, out)
		}
	}
	t.Setenv("SOPS_AGE_KEY_FILE", ageKey)
	t.Setenv("SOPS_WORK_AGE_KEY_FILE", workKey)
	t.Setenv("ANGST_PROJECTS_STORE", store)
	t.Setenv("ANGST_PROJECTS_REPO", repo)
	t.Setenv("ANGST_PROJECTS_ROOT", root)

	seed := func(s scope.Scope, id, name, repoURL, env string) {
		dir := filepath.Join(store, string(s), id)
		os.MkdirAll(dir, 0o700)
		meta := `{"name": "` + name + `", "repo": "` + repoURL + `"}
`
		os.WriteFile(filepath.Join(dir, "metadata.yaml"), []byte(meta), 0o600)
		os.WriteFile(filepath.Join(dir, "env"), []byte(env), 0o600)
	}
	seed(scope.Personal, "pid", "vault-personal", "git@example.invalid:vault/personal.git", "PERSONAL_KEY=one\n")
	seed(scope.Work, "wid", "vault-work", "git@work.example.invalid:vault/work.git", "WORK_KEY=two-ö\n")

	// Preserve the pristine store for the byte-exact comparison.
	orig := filepath.Join(home, "store.orig")
	if err := cpDir(store, orig); err != nil {
		t.Fatal(err)
	}

	// Encrypt each scope into its tarball and stage it in the repo store.
	for _, s := range []scope.Scope{scope.Personal, scope.Work} {
		if rc := vault.Run([]string{"encrypt", filepath.Join(store, string(s)), "--dir", "--scope", string(s)}); rc != 0 {
			t.Fatalf("vault encrypt --dir %s rc = %d", s, rc)
		}
		tarball := filepath.Join(store, string(s)+".tar.age")
		if _, err := os.Stat(tarball); err != nil {
			t.Fatalf("tarball not created: %v", err)
		}
		if err := os.MkdirAll(repo, 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(tarball, filepath.Join(repo, string(s)+".tar.age")); err != nil {
			t.Fatal(err)
		}
	}

	// Wipe the working store, then import from the tarballs.
	if err := os.RemoveAll(store); err != nil {
		t.Fatal(err)
	}
	if rc := cmdImport(nil); rc != 0 {
		t.Fatalf("cmdImport rc = %d", rc)
	}

	// Byte-exact round trip of metadata + env.
	assertTreeEqual(t, orig, store)

	// Sync materializes `.env` into pre-seeded clone roots.
	for _, name := range []string{"vault-personal", "vault-work"} {
		clone := filepath.Join(root, name)
		os.MkdirAll(clone, 0o755)
		os.MkdirAll(filepath.Join(clone, ".git"), 0o755)
	}
	if rc := cmdSync(nil); rc != 0 {
		t.Fatalf("cmdSync rc = %d", rc)
	}
	for name, want := range map[string]string{
		"vault-personal": "PERSONAL_KEY=one",
		"vault-work":     "WORK_KEY=two-ö",
	} {
		target := filepath.Join(root, name, ".env")
		if perm := permOf(t, target); perm != 0o600 {
			t.Fatalf("%s/.env perm = %#o, want 600", name, perm)
		}
		if !contains(t, target, want) {
			t.Fatalf("%s/.env missing %q", name, want)
		}
	}
}

func cpDir(src, dst string) error {
	return filepath.Walk(src, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, p)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if fi.IsDir() {
			return os.MkdirAll(target, 0o700)
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		if err := os.WriteFile(target, data, fi.Mode().Perm()); err != nil {
			return err
		}
		return os.Chmod(target, fi.Mode().Perm())
	})
}

func assertTreeEqual(t *testing.T, a, b string) {
	t.Helper()
	filepath.Walk(a, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if fi.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(a, p)
		q := filepath.Join(b, rel)
		da, errA := os.ReadFile(p)
		db, errB := os.ReadFile(q)
		if errA != nil || errB != nil {
			t.Fatalf("round-trip mismatch: %s (missing in result)", rel)
		}
		if !reflect.DeepEqual(da, db) {
			t.Fatalf("round-trip mismatch: %s content differs", rel)
		}
		return nil
	})
}

func permOf(t *testing.T, p string) os.FileMode {
	t.Helper()
	st, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}
	return st.Mode().Perm()
}

func contains(t *testing.T, p, needle string) bool {
	t.Helper()
	data, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return strings.Contains(string(data), needle)
}
