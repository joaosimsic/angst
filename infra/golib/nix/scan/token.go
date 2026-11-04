package scan

type tokenKind string

const (
	kindIdent  tokenKind = "ident"
	kindPath   tokenKind = "path"
	kindString tokenKind = "string"
	kindNumber tokenKind = "number"
	kindSymbol tokenKind = "sym"
)

type token struct {
	Kind tokenKind
	Text string
}

func (candidate token) isIdent(text string) bool {
	return candidate.Kind == kindIdent && candidate.Text == text
}

func (candidate token) isSymbol(text string) bool {
	return candidate.Kind == kindSymbol && candidate.Text == text
}

func tokenAt(tokens []token, index int) (token, bool) {
	if index < 0 || index >= len(tokens) {
		return token{}, false
	}

	return tokens[index], true
}
