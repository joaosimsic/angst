package scan

import (
	"slices"
	"testing"
)

func tokenTexts(t *testing.T, input string) []string {
	t.Helper()
	tokens, err := tokenize(input)
	if err != nil {
		t.Fatalf("tokenize(%q): %v", input, err)
	}

	texts := make([]string, 0, len(tokens))
	for _, current := range tokens {
		texts = append(texts, string(current.Kind)+":"+current.Text)
	}

	return texts
}

func TestTokenize(t *testing.T) {
	testCases := []struct {
		name  string
		input string
		want  []string
	}{
		{"whitespace", " \t\n", nil},
		{"line comment", "# comment\nname", []string{"ident:name"}},
		{"block comment", "/* comment */name", []string{"ident:name"}},
		{"quoted string", `"text"`, []string{"string:"}},
		{"indented string", "''text''", []string{"string:"}},
		{"angle path", "<nixpkgs>", []string{"path:<nixpkgs>"}},
		{"relative path", "/tmp/repo/file.nix", []string{"path:/tmp/repo/file.nix"}},
		{"identifier", "foo-bar'", []string{"ident:foo-bar'"}},
		{"number", "12.3", []string{"number:12.3"}},
		{"symbol", "+", []string{"sym:+"}},
		{"unterminated angle", "<", []string{"sym:<"}},
		{"double slash", "//", []string{"sym:/", "sym:/"}},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			if got := tokenTexts(t, testCase.input); !slices.Equal(got, testCase.want) {
				t.Fatalf("tokenize(%q) = %v, want %v", testCase.input, got, testCase.want)
			}
		})
	}
}

func TestTokenizeUnexpectedByte(t *testing.T) {
	for _, input := range []string{"'", "$", "\x00"} {
		if _, err := tokenize(input); err == nil {
			t.Fatalf("tokenize(%q) = nil error, want error", input)
		}
	}
}
