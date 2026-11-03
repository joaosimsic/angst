package logger_test

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"

	"github.com/joaosimsic/angst/infra/logger"
)

type vocabulary struct {
	LogCodes  []string `json:"logCodes"`
	LogLevels []string `json:"logLevels"`
}

func loadVocab(t *testing.T) vocabulary {
	t.Helper()
	raw, err := os.ReadFile("../contracts/log-vocab.json")
	if err != nil {
		t.Fatalf("read log-vocab.json: %v", err)
	}

	var result vocabulary
	if err := json.Unmarshal(raw, &result); err != nil {
		t.Fatalf("parse log-vocab.json: %v", err)
	}

	return result
}

func TestVocabParity(t *testing.T) {
	result := loadVocab(t)
	if !reflect.DeepEqual(logger.LogCodes(), result.LogCodes) {
		t.Fatalf("LogCodes drift: go=%v json=%v", logger.LogCodes(), result.LogCodes)
	}

	if !reflect.DeepEqual(logger.LogLevels(), result.LogLevels) {
		t.Fatalf("LogLevels drift: go=%v json=%v", logger.LogLevels(), result.LogLevels)
	}
}

func TestLevelWireValues(t *testing.T) {
	if string(logger.LevelError) != "error" || string(logger.LevelWarn) != "warn" || string(logger.LevelInfo) != "info" || string(logger.LevelStep) != "step" {
		t.Fatalf("Level wire values must be lowercase error/warn/info/step")
	}

	for _, level := range []string{"error", "warn", "info", "step"} {
		if !logger.IsLogLevel(level) {
			t.Fatalf("IsLogLevel(%q) = false, want true", level)
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
	codes := logger.LogCodes()
	codes[0] = "MUT"

	if logger.LogCodes()[0] == "MUT" {
		t.Fatalf("LogCodes() must return a clone")
	}
}
