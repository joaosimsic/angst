package logger_test

import (
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

var (
	phaseStateAssignment = regexp.MustCompile(`(?m)^\s*(phase|state)\s*=\s*"`)
	phaseStateDefinition = regexp.MustCompile(`(?m)^\s*(phases|states)\s*=`)
	vocabularyDefinition = regexp.MustCompile(`(?m)^\s*(SecretRef|logCodes|logLevels|secretFiles|secretInventory|secretSlugs)\s*=`)
)

func repoRoot(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}

	return root
}

func trackedNixFiles(t *testing.T, root string) []string {
	t.Helper()
	output, err := exec.Command("git", "-C", root, "ls-files", "-z", "--", "*.nix").Output()
	if err != nil {
		t.Fatalf("git ls-files: %v", err)
	}

	entries := strings.Split(strings.TrimSuffix(string(output), "\x00"), "\x00")
	files := make([]string, 0, len(entries))

	for _, file := range entries {
		if file != "" {
			files = append(files, file)
		}
	}

	return files
}

func isTestNixPath(file string) bool {
	base := path.Base(file)
	if base == "test.nix" || strings.HasSuffix(base, ".test.nix") || strings.HasSuffix(base, "_test.nix") {
		return true
	}

	for part := range strings.SplitSeq(file, "/") {
		switch part {
		case "tests", "testdata", "fixtures":
			return true
		}
	}

	return false
}

func isPhaseStatePathAllowed(file string) bool {
	return strings.HasPrefix(file, "workflow/") || strings.HasPrefix(file, "infra/logger/")
}

func isVocabularyPathAllowed(file string) bool {
	return strings.HasPrefix(file, "infra/contracts/") || strings.HasPrefix(file, "infra/logger/")
}

func phaseStateViolations(file, content string) []string {
	if isTestNixPath(file) || isPhaseStatePathAllowed(file) {
		return nil
	}

	violations := make([]string, 0, 2)
	if phaseStateAssignment.MatchString(content) {
		violations = append(violations, "ARCH: phase/state literal outside workflow/ and infra/logger/")
	}
	if phaseStateDefinition.MatchString(content) {
		violations = append(violations, "ARCH: phase/state definition outside workflow/phases.nix")
	}

	return violations
}

func vocabularyViolations(file, content string) []string {
	if isTestNixPath(file) || isVocabularyPathAllowed(file) {
		return nil
	}
	if !vocabularyDefinition.MatchString(content) {
		return nil
	}

	return []string{"ARCH: log vocabulary definition outside infra/contracts/ and infra/logger/"}
}

func TestArchRepositorySplit(t *testing.T) {
	root := repoRoot(t)

	for _, file := range trackedNixFiles(t, root) {
		if isTestNixPath(file) {
			continue
		}

		raw, err := os.ReadFile(filepath.Join(root, file))
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}

		violations := phaseStateViolations(file, string(raw))
		violations = append(violations, vocabularyViolations(file, string(raw))...)

		for _, violation := range violations {
			t.Errorf("%s: %s", file, violation)
		}
	}
}
