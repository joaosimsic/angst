package scan

type importTarget struct {
	pathToken token
	consumed  int
}

var directImportPattern = tokenPattern{
	matchers: []tokenMatcher{
		{kind: kindIdent, text: importKeyword},
		{kind: kindPath},
	},
	targetIndex: 1,
}

var parenthesizedImportPattern = tokenPattern{
	matchers: []tokenMatcher{
		{text: openParenthesisSymbol},
		{kind: kindIdent, text: importKeyword},
		{kind: kindPath},
		{text: closeParenthesisSymbol},
	},
	targetIndex: 2,
}

func matchImportTarget(tokens []token, start int) (importTarget, bool) {
	if match, ok := directImportPattern.match(tokens, start); ok {
		return importTarget{pathToken: match.target, consumed: len(directImportPattern.matchers)}, true
	}

	match, ok := parenthesizedImportPattern.match(tokens, start)
	if !ok {
		return importTarget{}, false
	}

	return importTarget{pathToken: match.target, consumed: len(parenthesizedImportPattern.matchers)}, true
}
