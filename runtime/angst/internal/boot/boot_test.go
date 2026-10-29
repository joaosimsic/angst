package boot

import (
	"path/filepath"
	"reflect"
	"testing"
)

func TestPasswordKeyFiles(t *testing.T) {
	home := "/tmp/home"
	got, ok := passwordKeyFiles("", "personal,work", home)
	want := []string{
		filepath.Join(home, ".config", "age", "keys.txt"),
		filepath.Join(home, ".config", "age", "work-keys.txt"),
	}
	if !ok || !reflect.DeepEqual(got, want) {
		t.Fatalf("key files = %v, ok=%v", got, ok)
	}

	got, ok = passwordKeyFiles("/explicit/key", "", home)
	if !ok || !reflect.DeepEqual(got, []string{"/explicit/key"}) {
		t.Fatalf("explicit key files = %v, ok=%v", got, ok)
	}

	if _, ok := passwordKeyFiles("", "", home); ok {
		t.Fatal("expected missing scopes to fail")
	}
}
