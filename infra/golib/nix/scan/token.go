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
