package scan

var aliasPattern = tokenPattern{
	matchers: []tokenMatcher{
		{kind: kindIdent},
		{text: assignmentSymbol},
		{text: openParenthesisSymbol},
		{kind: kindIdent, text: importKeyword},
		{kind: kindPath},
		{text: closeParenthesisSymbol},
	},
	targetIndex: 4,
	nameIndex:   0,
}

func (scanner *importScanner) scanAlias(tokens []token, start int) {
	match, ok := aliasPattern.match(tokens, start)
	if !ok || match.name.isIdent(importKeyword) {
		return
	}

	if start > 0 && tokens[start-1].isSymbol(fieldAccessSymbol) {
		return
	}

	target := relativePath(scanner.worktree, match.target.Text)

	scanner.findings.addAlias(match.name.Text, target)
}
