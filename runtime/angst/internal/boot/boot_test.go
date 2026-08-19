package boot

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetPasswordFieldReplace(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "default.nix")
	content := `{
  type = "nixos";
  hostname = "nixos";
  password = "old";
}
`
	os.WriteFile(p, []byte(content), 0o644)
	if err := setPasswordField(p, "NEWHASH"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(p)
	if !strings.Contains(string(data), `password = "NEWHASH";`) {
		t.Fatalf("replacement missing: %s", data)
	}
	if strings.Contains(string(data), "old") {
		t.Fatalf("old hash not replaced: %s", data)
	}
}

func TestSetPasswordFieldInsert(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "default.nix")
	content := `{
  type = "home";
  username = "joao";
  theme = "monochrome";
}
`
	os.WriteFile(p, []byte(content), 0o644)
	if err := setPasswordField(p, "NEWHASH"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(p)
	want := `  password = "NEWHASH";
`
	if !strings.Contains(string(data), want) {
		t.Fatalf("insertion wrong: %s", data)
	}
	if strings.Count(string(data), "}") != 1 {
		t.Fatalf("brace structure changed: %s", data)
	}
	if !strings.HasSuffix(string(data), "}\n") {
		t.Fatalf("decl close moved: %s", data)
	}
}
