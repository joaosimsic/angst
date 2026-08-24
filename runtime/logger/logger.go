package logger

import (
	"regexp"
	"strings"
)

type Level string

const (
	ERROR Level = "ERROR"
	WARN  Level = "WARN"
	STEP  Level = "STEP"
	INFO  Level = "INFO"
)

var (
	reError = regexp.MustCompile(`(?i)(error|panic|failed|fatal|invalid nushell)`)
	reWarn  = regexp.MustCompile(`(?i)warn`)
	reStep  = regexp.MustCompile(`(?i)(starting home manager|activating|symlinking|setting up|creating|installing|healthcheck)`)
)

func LevelOf(line string) Level {
	l := strings.ToLower(line)
	if reError.MatchString(l) {
		return ERROR
	}
	if reWarn.MatchString(l) {
		return WARN
	}
	if reStep.MatchString(l) {
		return STEP
	}
	return INFO
}

const (
	ansiReset      = "\033[0m"
	ansiRedBold    = "\033[1;31m"
	ansiYellowBold = "\033[1;33m"
	ansiCyanBold   = "\033[1;36m"
	ansiDarkGray   = "\033[90m"
	ansiGreenBold  = "\033[1;32m"
	ansiGreen      = "\033[32m"
)

func ColorBadge(level Level) string {
	switch level {
	case ERROR:
		return ansiRedBold
	case WARN:
		return ansiYellowBold
	case STEP:
		return ansiCyanBold
	default:
		return ansiDarkGray
	}
}

func Reset() string     { return ansiReset }
func GreenBold() string { return ansiGreenBold }
func Green() string     { return ansiGreen }
func DarkGray() string  { return ansiDarkGray }
