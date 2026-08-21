package scope

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAgeKeyfile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("ANGST_AGE_KEY_FILE", "")
	t.Setenv("ANGST_WORK_AGE_KEY_FILE", "")

	personal := filepath.Join(home, ".config", "age", "keys.txt")
	work := filepath.Join(home, ".config", "age", "work-keys.txt")
	if got := AgeKeyfile(Personal, EnvOverride); got != personal {
		t.Fatalf("personal = %q", got)
	}
	if got := AgeKeyfile(Work, EnvOverride); got != work {
		t.Fatalf("work = %q", got)
	}

	os.Setenv("ANGST_WORK_AGE_KEY_FILE", "/env/work-keys.txt")
	if got := AgeKeyfile(Work, EnvOverride); got != "/env/work-keys.txt" {
		t.Fatalf("work env override = %q", got)
	}
	if got := AgeKeyfile(Work, Fixed); got != work {
		t.Fatalf("work fixed = %q", got)
	}
}

func TestSSHKeyfile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("ANGST_SSH_KEY", "")
	t.Setenv("ANGST_WORK_SSH_KEY", "")

	if got := SSHKeyfile(Personal); got != filepath.Join(home, ".ssh", "id_ed25519") {
		t.Fatalf("personal = %q", got)
	}
	os.Setenv("ANGST_WORK_SSH_KEY", "/x/work")
	if got := SSHKeyfile(Work); got != "/x/work" {
		t.Fatalf("work = %q", got)
	}
}

func TestValid(t *testing.T) {
	if !Valid("personal") || !Valid("work") {
		t.Fatal("valid scopes rejected")
	}
	if Valid("") || Valid("Personal") || Valid("other") {
		t.Fatal("invalid scope accepted")
	}
}
