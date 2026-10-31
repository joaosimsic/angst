package logger_test

import (
	"bytes"
	"encoding/json"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"

	"logger"
)

type vocab struct {
	LogCodes  []string `json:"logCodes"`
	LogLevels []string `json:"logLevels"`
}

func loadVocab(t *testing.T) vocab {
	t.Helper()
	raw, err := os.ReadFile("../contracts/log-vocab.json")
	if err != nil {
		t.Fatalf("read log-vocab.json: %v", err)
	}
	var v vocab
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatalf("parse log-vocab.json: %v", err)
	}
	return v
}

func TestVocabParity(t *testing.T) {
	v := loadVocab(t)
	if !reflect.DeepEqual(logger.LogCodes(), v.LogCodes) {
		t.Fatalf("LogCodes drift: go=%v json=%v", logger.LogCodes(), v.LogCodes)
	}
	if !reflect.DeepEqual(logger.LogLevels(), v.LogLevels) {
		t.Fatalf("LogLevels drift: go=%v json=%v", logger.LogLevels(), v.LogLevels)
	}
}

func loadNixStrings(t *testing.T, expr string) []string {
	t.Helper()
	if _, err := exec.LookPath("nix"); err != nil {
		t.Skip("nix binary missing, log domain Nix parity enforced in CI")
	}
	// Test runs in infra/logger; repo root is ../../ from package dir.
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}
	cmd := exec.Command("nix", "eval", "--impure", "--json", "--expr", expr)
	cmd.Dir = root
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("nix eval %s: %v: %s", expr, err, stderr.String())
	}
	var out []string
	if err := json.Unmarshal(stdout.Bytes(), &out); err != nil {
		t.Fatalf("parse nix eval %s: %v: %s", expr, err, stdout.String())
	}
	return out
}

func TestNixParity(t *testing.T) {
	v := loadVocab(t)
	nixCodes := loadNixStrings(t, "(import ./infra/logger/default.nix).logCodes")
	nixLevels := loadNixStrings(t, "(import ./infra/logger/default.nix).logLevels")
	if !reflect.DeepEqual(nixCodes, v.LogCodes) {
		t.Fatalf("Nix logCodes drift: nix=%v json=%v", nixCodes, v.LogCodes)
	}
	if !reflect.DeepEqual(nixLevels, v.LogLevels) {
		t.Fatalf("Nix logLevels drift: nix=%v json=%v", nixLevels, v.LogLevels)
	}
	if !reflect.DeepEqual(nixCodes, logger.LogCodes()) {
		t.Fatalf("Nix vs Go logCodes drift: nix=%v go=%v", nixCodes, logger.LogCodes())
	}
	if !reflect.DeepEqual(nixLevels, logger.LogLevels()) {
		t.Fatalf("Nix vs Go logLevels drift: nix=%v go=%v", nixLevels, logger.LogLevels())
	}
}

func TestLevelWireValues(t *testing.T) {
	if string(logger.LevelError) != "error" || string(logger.LevelWarn) != "warn" || string(logger.LevelInfo) != "info" || string(logger.LevelStep) != "step" {
		t.Fatalf("Level wire values must be lowercase error/warn/info/step")
	}
	for _, l := range []string{"error", "warn", "info", "step"} {
		if !logger.IsLogLevel(l) {
			t.Fatalf("IsLogLevel(%q) = false, want true", l)
		}
	}
	if logger.IsLogLevel("bogus") {
		t.Fatalf("IsLogLevel(bogus) = true, want false")
	}
}

func TestLogCodesStable(t *testing.T) {
	want := []string{"TGT", "PKG", "PROF", "DESK", "CTX", "SEC", "VM", "PROJ", "DEP", "ACT", "LOG", "ARCH"}
	if !reflect.DeepEqual(logger.LogCodes(), want) {
		t.Fatalf("logCodes changed: got %v want %v (update JSON + Nix + Go together)", logger.LogCodes(), want)
	}
}

func TestImmutability(t *testing.T) {
	a := logger.LogCodes()
	a[0] = "MUT"
	if logger.LogCodes()[0] == "MUT" {
		t.Fatalf("LogCodes() must return a clone")
	}
}

// fixtureSlugs mirrors the secrets/ stub inventory. loadSecretsSlugs guards drift.
func fixtureSlugs() []string {
	return []string{"cursor-api-key", "example", "opencode-go-key", "personal.ed25519", "work.ed25519"}
}

func stripSecretSuffix(base string) string {
	for _, suf := range []string{".placeholder", ".age", ".pub"} {
		base = strings.TrimSuffix(base, suf)
	}
	return base
}

func loadSecretsSlugs(t *testing.T) []string {
	t.Helper()
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}
	var out []string
	err = filepath.WalkDir(filepath.Join(root, "secrets"), func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		name := d.Name()
		if !(strings.HasSuffix(name, ".age") || strings.HasSuffix(name, ".placeholder") || strings.HasSuffix(name, ".pub")) {
			return nil
		}
		out = append(out, stripSecretSuffix(name))
		return nil
	})
	if err != nil {
		t.Fatalf("walk secrets/: %v", err)
	}
	sort.Strings(out)
	out = uniqueSorted(out)
	return out
}

func uniqueSorted(in []string) []string {
	var out []string
	for _, s := range in {
		if len(out) == 0 || out[len(out)-1] != s {
			out = append(out, s)
		}
	}
	return out
}

func TestSecretsInventoryNoDrift(t *testing.T) {
	if got, want := loadSecretsSlugs(t), fixtureSlugs(); !reflect.DeepEqual(got, want) {
		t.Fatalf("secrets/ inventory drift: dir=%v fixture=%v (update fixture + Nix tests together)", got, want)
	}
}

func TestIsKnownSecretRefExact(t *testing.T) {
	slugs := fixtureSlugs()
	for _, s := range []string{"opencode-go-key", "cursor-api-key", "example", "personal.ed25519", "work.ed25519"} {
		if !logger.IsKnownSecretRef(s, slugs) {
			t.Fatalf("IsKnownSecretRef(%q) = false, want true", s)
		}
	}
	for _, s := range []string{"password", "apiKey", "token", "authToken", "foo", "host", "author", "Opencode-Go-Key", "", "nope"} {
		if logger.IsKnownSecretRef(s, slugs) {
			t.Fatalf("IsKnownSecretRef(%q) = true, want false (exact inventory match only)", s)
		}
	}
}
