package scan

import (
	"testing"

	"github.com/joaosimsic/angst/infra/golib/repo"
)

func TestAnalyzeReferenceForms(t *testing.T) {
	worktree := repo.Worktree{Root: "/tmp/repo"}

	files := map[string]struct{}{
		"mod/default.nix": {},
		"mod/private.nix": {},
	}

	aliases := map[string]string{
		"mod": "mod/default.nix",
	}

	testCases := []struct {
		name             string
		parsedExpression string
		aliases          map[string]string
		target           string
		member           string
	}{
		{"direct", `(import /tmp/repo/mod/default.nix).direct`, nil, "mod/default.nix", "direct"},
		{"double paren", `((import /tmp/repo/mod/private.nix)).double`, nil, "mod/private.nix", "double"},
		{"alias call", `(mod).called`, aliases, "mod/default.nix", "called"},
		{"alias field", `mod.field`, aliases, "mod/default.nix", "field"},
		{"alias field before end", `mod.field;`, aliases, "mod/default.nix", "field"},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			tokens, err := tokenize(testCase.parsedExpression)
			if err != nil {
				t.Fatalf("tokenize: %v", err)
			}

			result := analyzeReferences(worktree, files, testCase.aliases, tokens)
			if _, ok := result[testCase.target][testCase.member]; !ok {
				t.Fatalf("missing ref %s.%s: %#v", testCase.target, testCase.member, result)
			}
		})
	}
}
