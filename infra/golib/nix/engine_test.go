package nix

import "testing"

func TestQuote(t *testing.T) {
	cases := map[string]string{
		`plain`:      `plain`,
		`back\slash`: `back\\slash`,
		`a"b`:        `a\"b`,
		`${x}`:       `\${x}`,
	}

	for input, want := range cases {
		if got := Quote(input); got != want {
			t.Fatalf("Quote(%q) = %q, want %q", input, got, want)
		}
	}
}
