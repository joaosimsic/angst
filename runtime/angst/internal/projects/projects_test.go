package projects

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
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

func TestMissingKeys(t *testing.T) {
	dir := t.TempDir()
	ex := filepath.Join(dir, "ex")
	env := filepath.Join(dir, "env")
	os.WriteFile(ex, []byte("A=1\nB=2\nC=3\n"), 0o600)
	os.WriteFile(env, []byte("A=1\n"), 0o600)
	got := missingKeys(ex, env)
	if !reflect.DeepEqual(got, []string{"B", "C"}) {
		t.Fatalf("missingKeys = %v, want [B C]", got)
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

func TestSopsRoundTrip(t *testing.T) {
	for _, bin := range []string{"sops", "age", "age-keygen"} {
		if _, err := exec.LookPath(bin); err != nil {
			t.Skipf("%s not on PATH; skipping sops round-trip", bin)
		}
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	os.MkdirAll(filepath.Join(home, ".config", "sops", "age"), 0o700)
	keysFile := filepath.Join(home, ".config", "sops", "age", "keys.txt")
	if out, err := exec.Command("age-keygen", "-o", keysFile).Output(); err != nil {
		t.Fatalf("age-keygen: %v (%s)", err, out)
	}

	plain := filepath.Join(home, "plain")
	payload := []byte("metadata-key: value\nunicode-ö-✓\n")
	if err := os.WriteFile(plain, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(home, "encrypted")

	if err := encrypt("personal", plain, target); err != nil {
		t.Fatalf("encrypt failed: %v", err)
	}
	got, err := sopsDecrypt("personal", target)
	if err != nil {
		t.Fatalf("decrypt failed: %v", err)
	}
	if !reflect.DeepEqual(got, payload) {
		t.Fatalf("round-trip mismatch: %q != %q", got, payload)
	}
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
