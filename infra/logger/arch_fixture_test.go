package logger_test

import (
	"fmt"
	"testing"
)

func TestArchLiteralFixtures(t *testing.T) {
	cases := []struct {
		name       string
		file       string
		content    string
		violations int
	}{
		{
			name:       "phase outside workflow",
			file:       "compose/context/default.nix",
			content:    `phase = "validate";`,
			violations: 1,
		},
		{
			name:       "phase inside workflow",
			file:       "workflow/activate/default.nix",
			content:    `phase = "activate";`,
			violations: 0,
		},
		{
			name:       "phase in test",
			file:       "infra/logger/test.nix",
			content:    `phase = "validate";`,
			violations: 0,
		},
		{
			name:       "duplicate phases",
			file:       "compose/context/default.nix",
			content:    `phases = [ "evaluate" ];`,
			violations: 1,
		},
		{
			name:       "vocabulary outside contracts",
			file:       "compose/context/default.nix",
			content:    `logCodes = [ "TGT" ];`,
			violations: 1,
		},
		{
			name:       "vocabulary in contracts",
			file:       "infra/contracts/codes.nix",
			content:    `logCodes = [ "TGT" ];`,
			violations: 0,
		},
		{
			name:       "vocabulary re-export in logger",
			file:       "infra/logger/default.nix",
			content:    `logCodes = [ "TGT" ];`,
			violations: 0,
		},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			violations := phaseStateViolations(testCase.file, testCase.content)
			violations = append(violations, vocabularyViolations(testCase.file, testCase.content)...)
			if len(violations) != testCase.violations {
				t.Fatalf("got %v, want %d violations", violations, testCase.violations)
			}
		})
	}
}

func TestArchFixtureMessage(t *testing.T) {
	violations := phaseStateViolations("compose/context/default.nix", `phase = "validate";`)
	if len(violations) != 1 {
		t.Fatalf("got %v, want one violation", violations)
	}

	want := "ARCH: phase/state literal outside workflow/ and infra/logger/"
	if fmt.Sprint(violations[0]) != want {
		t.Fatalf("got %q, want %q", violations[0], want)
	}
}
