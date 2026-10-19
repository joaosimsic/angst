package ftp

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeConf(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "conf.json")
	if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestTransformOrderedKeys(t *testing.T) {
	conf := writeConf(t, `{"remote": "angstci", "path": "/incoming", "config": {"type": "ftp", "host": "127.0.0.1", "user": "ci", "pass": "ci-secret-pass", "port": "2121"}}`)
	remote, path, ini, err := Transform(conf)
	if err != nil {
		t.Fatal(err)
	}
	if remote != "angstci" || path != "/incoming" {
		t.Fatalf("remote/path = %q/%q", remote, path)
	}
	want := "[angstci]\ntype = ftp\nhost = 127.0.0.1\nuser = ci\npass = ci-secret-pass\nport = 2121\n"
	if string(ini) != want {
		t.Fatalf("ini = %q, want %q", ini, want)
	}
}

func TestTransformPathDefault(t *testing.T) {
	conf := writeConf(t, `{"remote": "x", "config": {"type": "ftp"}}`)
	_, path, _, err := Transform(conf)
	if err != nil {
		t.Fatal(err)
	}
	if path != "/" {
		t.Fatalf("path = %q, want /", path)
	}
}

func TestTransformScalarTypes(t *testing.T) {
	conf := writeConf(t, `{"remote": "x", "config": {"num": 2121, "frac": 0.5, "yes": true, "no": false, "nil": null, "arr": ["a", "b"]}}`)
	_, _, ini, err := Transform(conf)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(ini)), "\n")
	expect := []string{
		"[x]",
		"num = 2121",
		"frac = 0.5",
		"yes = true",
		"no = false",
		"nil = null",
		`arr = ["a","b"]`,
	}
	if len(lines) != len(expect) {
		t.Fatalf("ini lines = %v", lines)
	}
	for i := range expect {
		if lines[i] != expect[i] {
			t.Fatalf("line %d = %q, want %q", i, lines[i], expect[i])
		}
	}
}

func TestTransformMissingFile(t *testing.T) {
	_, _, _, err := Transform(filepath.Join(t.TempDir(), "nope.json"))
	if err == nil {
		t.Fatal("expected error for missing conf")
	}
}

func TestJqTostringFallbackOrderedObject(t *testing.T) {
	v := orderedMap{{"z", "1"}, {"a", "2"}}
	got := jqTostring(v)
	if got != `{"z":"1","a":"2"}` {
		t.Fatalf("jqTostring(orderedMap) = %q", got)
	}
}
