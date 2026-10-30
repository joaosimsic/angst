package logger

import "strings"

// Level is the wire log level. Canonical wire values are lowercase,
// matching infra/contracts/log-vocab.json and Nix logLevels.
type Level string

const (
	LevelError Level = "error"
	LevelWarn  Level = "warn"
	LevelInfo  Level = "info"
	LevelStep  Level = "step"
)

// LogCodes returns the 12 log code prefixes. Returns a clone;
// caller cannot mutate embedded vocab.
func LogCodes() []string {
	out := make([]string, len(generatedLogCodes))
	copy(out, generatedLogCodes)
	return out
}

// LogLevels returns the wire level values. Returns a clone.
func LogLevels() []string {
	out := make([]string, len(generatedLogLevels))
	copy(out, generatedLogLevels)
	return out
}

// IsLogLevel reports whether s is a known wire level.
func IsLogLevel(s string) bool {
	for _, l := range generatedLogLevels {
		if s == l {
			return true
		}
	}
	return false
}

// IsLogCodePrefix reports whether s is a known code prefix.
func IsLogCodePrefix(s string) bool {
	for _, c := range generatedLogCodes {
		if s == c {
			return true
		}
	}
	return false
}

// LevelOf maps a backend line to a Level. Backend-agnostic fallback:
// error/fail -> ERROR, warn -> WARN, step/==> -> STEP, else INFO.
func LevelOf(line string) Level {
	l := strings.ToLower(line)
	switch {
	case strings.Contains(l, "error") || strings.Contains(l, "fail"):
		return LevelError
	case strings.Contains(l, "warn"):
		return LevelWarn
	case strings.Contains(l, "step") || strings.Contains(l, "==>"):
		return LevelStep
	default:
		return LevelInfo
	}
}
