package logger_test

import (
	"bytes"
	"encoding/json"
	"os/exec"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/joaosimsic/angst/infra/logger"
)

func loadNixStrings(t *testing.T, expression string) []string {
	t.Helper()
	if _, err := exec.LookPath("nix"); err != nil {
		t.Skip("nix binary missing, log domain Nix parity enforced in CI")
	}

	// Test runs in infra/logger; repo root is ../../ from package dir.
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}

	cmd := exec.Command("nix", "eval", "--impure", "--json", "--expr", expression)
	cmd.Dir = root

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		t.Fatalf("nix eval %s: %v: %s", expression, err, stderr.String())
	}

	var result []string
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("parse nix eval %s: %v: %s", expression, err, stdout.String())
	}

	return result
}

func TestNixParity(t *testing.T) {
	loadedVocabulary := loadVocab(t)
	nixCodes := loadNixStrings(t, "(import ./infra/logger/default.nix).logCodes")
	nixLevels := loadNixStrings(t, "(import ./infra/logger/default.nix).logLevels")

	if !reflect.DeepEqual(nixCodes, loadedVocabulary.LogCodes) {
		t.Fatalf("Nix logCodes drift: nix=%v json=%v", nixCodes, loadedVocabulary.LogCodes)
	}

	if !reflect.DeepEqual(nixLevels, loadedVocabulary.LogLevels) {
		t.Fatalf("Nix logLevels drift: nix=%v json=%v", nixLevels, loadedVocabulary.LogLevels)
	}

	if !reflect.DeepEqual(nixCodes, logger.LogCodes()) {
		t.Fatalf("Nix vs Go logCodes drift: nix=%v go=%v", nixCodes, logger.LogCodes())
	}

	if !reflect.DeepEqual(nixLevels, logger.LogLevels()) {
		t.Fatalf("Nix vs Go logLevels drift: nix=%v go=%v", nixLevels, logger.LogLevels())
	}
}
