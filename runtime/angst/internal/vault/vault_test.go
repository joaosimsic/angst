package vault

import (
	"bytes"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"angst/internal/scope"
	"angst/internal/shared"
)

// setupAgeKeys generates throwaway personal + work age identities in a temp
// HOME and points SOPS_AGE_KEY_FILE / SOPS_WORK_AGE_KEY_FILE at them. Tests
// that round-trip through the real `age` binary are skipped when age/age-keygen
// are not on PATH.
func setupAgeKeys(t *testing.T) {
	t.Helper()
	for _, bin := range []string{"age", "age-keygen"} {
		if _, err := exec.LookPath(bin); err != nil {
			t.Skipf("%s not on PATH; skipping vault age tests", bin)
		}
	}

	home := t.TempDir()
	t.Setenv("HOME", home)

	personal := filepath.Join(home, "keys.txt")
	work := filepath.Join(home, "work-keys.txt")
	for _, kf := range []string{personal, work} {
		if out, err := exec.Command("age-keygen", "-o", kf).CombinedOutput(); err != nil {
			t.Fatalf("age-keygen %s: %v (%s)", kf, err, out)
		}
	}

	t.Setenv("SOPS_AGE_KEY_FILE", personal)
	t.Setenv("SOPS_WORK_AGE_KEY_FILE", work)
}

func permOf(t *testing.T, p string) os.FileMode {
	t.Helper()
	st, err := os.Stat(p)
	if err != nil {
		t.Fatalf("stat %s: %v", p, err)
	}
	return st.Mode().Perm()
}

func captureStdout(t *testing.T, fn func()) string {
	t.Helper()
	orig := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w
	fn()
	w.Close()
	os.Stdout = orig

	var buf bytes.Buffer
	if _, err := io.Copy(&buf, r); err != nil {
		t.Fatal(err)
	}
	return buf.String()
}

// --- parseArgs -----------------------------------------------------------

func TestParseArgs(t *testing.T) {
	cases := []struct {
		name      string
		args      []string
		wantPath  string
		wantDir   bool
		wantForce bool
		wantDel   bool
		wantScope scope.Scope
		wantErr   string
	}{
		{"path only", []string{"foo"}, "foo", false, false, false, scope.Scope(""), ""},
		{"dir flag", []string{"--dir", "foo"}, "foo", true, false, false, scope.Scope(""), ""},
		{"force flag", []string{"--force", "foo"}, "foo", false, true, false, scope.Scope(""), ""},
		{"delete flag", []string{"foo", "--delete"}, "foo", false, false, true, scope.Scope(""), ""},
		{"scope work", []string{"--scope", "work", "foo"}, "foo", false, false, false, scope.Work, ""},
		{"scope personal", []string{"foo", "--scope", "personal"}, "foo", false, false, false, scope.Personal, ""},
		{"combined", []string{"--dir", "--force", "--scope", "work", "foo"}, "foo", true, true, false, scope.Work, ""},
		{"missing path", []string{"--force"}, "", false, false, false, scope.Scope(""), "path argument required"},
		{"invalid scope", []string{"--scope", "bogus", "foo"}, "", false, false, false, scope.Scope(""), "unknown scope"},
		{"scope no value", []string{"--scope"}, "", false, false, false, scope.Scope(""), "requires a value"},
		{"help", []string{"-h", "foo"}, "", false, false, false, scope.Scope(""), "help"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p, opts, err := parseArgs(c.args)
			if c.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), c.wantErr) {
					t.Fatalf("err = %v, want contains %q", err, c.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected err: %v", err)
			}
			if p != c.wantPath {
				t.Fatalf("path = %q, want %q", p, c.wantPath)
			}
			if opts.dirMode != c.wantDir {
				t.Fatalf("dirMode = %v, want %v", opts.dirMode, c.wantDir)
			}
			if opts.force != c.wantForce {
				t.Fatalf("force = %v, want %v", opts.force, c.wantForce)
			}
			if opts.delete != c.wantDel {
				t.Fatalf("delete = %v, want %v", opts.delete, c.wantDel)
			}
			if opts.sc != c.wantScope {
				t.Fatalf("scope = %q, want %q", opts.sc, c.wantScope)
			}
		})
	}
}

// --- file mode round-trip ------------------------------------------------

func TestEncryptDecryptFileRoundTrip(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "secret.yaml")
	payload := []byte("token: super-secret-ö\n")
	if err := os.WriteFile(src, payload, 0o600); err != nil {
		t.Fatal(err)
	}

	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	ageFile := src + ".age"
	if _, err := os.Stat(ageFile); err != nil {
		t.Fatalf("age file not created: %v", err)
	}
	if _, err := os.Stat(src); err != nil {
		t.Fatalf("source removed without --delete: %v", err)
	}
	data, err := os.ReadFile(ageFile)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(data, []byte("age-encryption.org/v1")) {
		t.Fatalf("age file is not age-encrypted")
	}
	if bytes.Contains(data, []byte("super-secret")) {
		t.Fatalf("plaintext leaked into age file")
	}

	if rc := Run([]string{"decrypt", ageFile}); rc != shared.ExitOK {
		t.Fatalf("decrypt rc = %d", rc)
	}
	got, err := os.ReadFile(src)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("round-trip mismatch: %q", got)
	}
	if perm := permOf(t, src); perm != 0o600 {
		t.Fatalf("decrypted perm = %#o, want 600", perm)
	}
}

func TestEncryptFilePerms(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(src, []byte("p"), 0o644); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	if perm := permOf(t, src+".age"); perm != 0o600 {
		t.Fatalf("age perm = %#o, want 600", perm)
	}
}

func TestEncryptFileDelete(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(src, []byte("gone"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src, "--delete"}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	if _, err := os.Stat(src); err == nil {
		t.Fatalf("source not deleted with --delete")
	}
	if _, err := os.Stat(src + ".age"); err != nil {
		t.Fatalf("age file not created: %v", err)
	}
}

// --- file mode on directories --------------------------------------------

func TestEncryptDecryptDirRoundTrip(t *testing.T) {
	setupAgeKeys(t)
	srcDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(srcDir, "a.txt"), []byte("alpha"), 0o600); err != nil {
		t.Fatal(err)
	}
	nested := filepath.Join(srcDir, "sub")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, "b.txt"), []byte("beta"), 0o600); err != nil {
		t.Fatal(err)
	}

	if rc := Run([]string{"encrypt", srcDir}); rc != shared.ExitOK {
		t.Fatalf("encrypt dir rc = %d", rc)
	}
	if _, err := os.Stat(filepath.Join(srcDir, "a.txt.age")); err != nil {
		t.Fatalf("a.txt.age missing: %v", err)
	}
	if _, err := os.Stat(filepath.Join(nested, "b.txt.age")); err != nil {
		t.Fatalf("b.txt.age missing: %v", err)
	}
	// File-mode keeps the original plaintext (only --delete removes it); the
	// .age ciphertext is what must be present and what gets restored on decrypt.
	if _, err := os.Stat(filepath.Join(srcDir, "a.txt.age")); err != nil {
		t.Fatalf("a.txt.age missing: %v", err)
	}

	if rc := Run([]string{"decrypt", srcDir}); rc != shared.ExitOK {
		t.Fatalf("decrypt dir rc = %d", rc)
	}
	gotA, err := os.ReadFile(filepath.Join(srcDir, "a.txt"))
	if err != nil {
		t.Fatal(err)
	}
	gotB, err := os.ReadFile(filepath.Join(nested, "b.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(gotA) != "alpha" || string(gotB) != "beta" {
		t.Fatalf("dir round-trip mismatch: %q / %q", gotA, gotB)
	}
}

func TestEncryptSkipsExisting(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(src, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("first encrypt rc = %d", rc)
	}
	if err := os.WriteFile(src+".age", []byte("TAMPERED"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("second encrypt rc = %d, want ExitOK (skip)", rc)
	}
	data, err := os.ReadFile(src + ".age")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "TAMPERED" {
		t.Fatalf("existing .age overwritten without --force")
	}
}

func TestForceOverwrite(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(src, []byte("original"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	if err := os.WriteFile(src+".age", []byte("TAMPERED"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src, "--force"}); rc != shared.ExitOK {
		t.Fatalf("force encrypt rc = %d", rc)
	}
	if rc := Run([]string{"decrypt", src + ".age"}); rc != shared.ExitOK {
		t.Fatalf("decrypt rc = %d", rc)
	}
	got, err := os.ReadFile(src)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "original" {
		t.Fatalf("force did not re-encrypt: %q", got)
	}
}

// --- directory mode (tar + age) ------------------------------------------

func TestDirModeRoundTrip(t *testing.T) {
	setupAgeKeys(t)
	srcDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(srcDir, "a.txt"), []byte("alpha"), 0o600); err != nil {
		t.Fatal(err)
	}
	nested := filepath.Join(srcDir, "sub")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(nested, "b.txt"), []byte("beta-ö"), 0o600); err != nil {
		t.Fatal(err)
	}

	if rc := Run([]string{"encrypt", srcDir, "--dir"}); rc != shared.ExitOK {
		t.Fatalf("encrypt --dir rc = %d", rc)
	}
	tarAge := srcDir + ".tar.age"
	if _, err := os.Stat(tarAge); err != nil {
		t.Fatalf("tar.age not created: %v", err)
	}
	if _, err := os.Stat(srcDir); err == nil {
		t.Fatalf("source dir not removed after --dir encrypt")
	}

	if rc := Run([]string{"decrypt", tarAge, "--dir"}); rc != shared.ExitOK {
		t.Fatalf("decrypt --dir rc = %d", rc)
	}
	gotA, err := os.ReadFile(filepath.Join(srcDir, "a.txt"))
	if err != nil {
		t.Fatal(err)
	}
	gotB, err := os.ReadFile(filepath.Join(nested, "b.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(gotA) != "alpha" || string(gotB) != "beta-ö" {
		t.Fatalf("dir-mode round-trip mismatch: %q / %q", gotA, gotB)
	}
}

// --- status --------------------------------------------------------------

func TestStatusFile(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	plain := filepath.Join(dir, "p.txt")
	if err := os.WriteFile(plain, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	out := captureStdout(t, func() {
		if rc := Run([]string{"status", plain}); rc != shared.ExitOK {
			t.Fatalf("status plain rc = %d", rc)
		}
	})
	if !strings.Contains(out, "plaintext") {
		t.Fatalf("status plain output = %q", out)
	}

	age := filepath.Join(dir, "e.txt.age")
	if err := os.WriteFile(age, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	out = captureStdout(t, func() {
		if rc := Run([]string{"status", age}); rc != shared.ExitOK {
			t.Fatalf("status age rc = %d", rc)
		}
	})
	if !strings.Contains(out, "encrypted") {
		t.Fatalf("status age output = %q", out)
	}
}

func TestStatusDir(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "b.txt.age"), []byte("y"), 0o600); err != nil {
		t.Fatal(err)
	}
	out := captureStdout(t, func() {
		if rc := Run([]string{"status", dir}); rc != shared.ExitOK {
			t.Fatalf("status dir rc = %d", rc)
		}
	})
	if !strings.Contains(out, "encrypted: 1, plaintext: 1") {
		t.Fatalf("status dir output = %q", out)
	}
}

// --- scope isolation ------------------------------------------------------

func TestScopeWork(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "w.txt")
	payload := []byte("work-secret")
	if err := os.WriteFile(src, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src, "--scope", "work"}); rc != shared.ExitOK {
		t.Fatalf("encrypt work rc = %d", rc)
	}
	if rc := Run([]string{"decrypt", src + ".age", "--scope", "work"}); rc != shared.ExitOK {
		t.Fatalf("decrypt work rc = %d", rc)
	}
	got, err := os.ReadFile(src)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("work scope round-trip mismatch: %q", got)
	}
}

func TestScopeMismatchFails(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "s.txt")
	if err := os.WriteFile(src, []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src, "--scope", "personal"}); rc != shared.ExitOK {
		t.Fatalf("encrypt personal rc = %d", rc)
	}
	if rc := Run([]string{"decrypt", src + ".age", "--scope", "work"}); rc == shared.ExitOK {
		t.Fatalf("decrypt with wrong scope should fail")
	}
}

// --- error paths ----------------------------------------------------------

func TestEncryptMissingPath(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	if rc := Run([]string{"encrypt", filepath.Join(dir, "nope.txt")}); rc != shared.ExitError {
		t.Fatalf("rc = %d, want ExitError", rc)
	}
}

func TestDecryptMissingPath(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	if rc := Run([]string{"decrypt", filepath.Join(dir, "nope.age")}); rc != shared.ExitError {
		t.Fatalf("rc = %d, want ExitError", rc)
	}
}

func TestDirModeOnFile(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	f := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(f, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", f, "--dir"}); rc != shared.ExitError {
		t.Fatalf("encrypt --dir on file rc = %d, want ExitError", rc)
	}
}

func TestDirModeOnNonTarAge(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	f := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(f, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"decrypt", f, "--dir"}); rc != shared.ExitError {
		t.Fatalf("decrypt --dir on non-tar.age rc = %d, want ExitError", rc)
	}
}

func TestUnknownCommand(t *testing.T) {
	if rc := Run([]string{"frobnicate", "x"}); rc != shared.ExitUsage {
		t.Fatalf("rc = %d, want ExitUsage", rc)
	}
}

// --- edge cases -----------------------------------------------------------

func TestEncryptDecryptEmpty(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "empty")
	if err := os.WriteFile(src, []byte{}, 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	if _, err := os.Stat(src + ".age"); err != nil {
		t.Fatalf("age file not created: %v", err)
	}
	if rc := Run([]string{"decrypt", src + ".age"}); rc != shared.ExitOK {
		t.Fatalf("decrypt rc = %d", rc)
	}
	info, err := os.Stat(src)
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() != 0 {
		t.Fatalf("empty file size = %d", info.Size())
	}
}

func TestEncryptDecryptBinary(t *testing.T) {
	setupAgeKeys(t)
	dir := t.TempDir()
	src := filepath.Join(dir, "bin")
	payload := []byte{0x00, 0x01, 0xff, 0xfe, 0x00, 0x42}
	if err := os.WriteFile(src, payload, 0o600); err != nil {
		t.Fatal(err)
	}
	if rc := Run([]string{"encrypt", src}); rc != shared.ExitOK {
		t.Fatalf("encrypt rc = %d", rc)
	}
	if rc := Run([]string{"decrypt", src + ".age"}); rc != shared.ExitOK {
		t.Fatalf("decrypt rc = %d", rc)
	}
	got, err := os.ReadFile(src)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("binary round-trip mismatch: %v", got)
	}
}
