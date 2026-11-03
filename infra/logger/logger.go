package logger

import (
	"slices"
	"strings"
)

type Level string

const (
	LevelError Level = "error"
	LevelWarn  Level = "warn"
	LevelInfo  Level = "info"
	LevelStep  Level = "step"
)

func LogCodes() []string {
	return slices.Clone(generatedLogCodes)
}

func LogLevels() []string {
	return slices.Clone(generatedLogLevels)
}

func IsLogLevel(value string) bool {
	return slices.Contains(generatedLogLevels, value)
}

func IsLogCodePrefix(value string) bool {
	return slices.Contains(generatedLogCodes, value)
}

func IsKnownSecretRef(ref string, slugs []string) bool {
	if ref == "" {
		return false
	}

	return slices.Contains(slugs, ref)
}

func LevelOf(line string) Level {
	lowercaseLine := strings.ToLower(line)
	switch {
	case strings.Contains(lowercaseLine, "error") || strings.Contains(lowercaseLine, "fail"):
		return LevelError
	case strings.Contains(lowercaseLine, "warn"):
		return LevelWarn
	case strings.Contains(lowercaseLine, "step") || strings.Contains(lowercaseLine, "==>"):
		return LevelStep
	default:
		return LevelInfo
	}
}
