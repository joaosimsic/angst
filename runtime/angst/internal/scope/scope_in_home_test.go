package scope

import (
	"path/filepath"
	"testing"
)

func TestAgeKeyfileInHome(t *testing.T) {
	home := "/tmp/example-home"
	if got := AgeKeyfileInHome(home, Personal, Fixed); got != filepath.Join(home, ".config", "age", "keys.txt") {
		t.Fatalf("personal = %q", got)
	}
	if got := AgeKeyfileInHome(home, Work, Fixed); got != filepath.Join(home, ".config", "age", "work-keys.txt") {
		t.Fatalf("work = %q", got)
	}
}
