package scan

type tokenMatcher struct {
	kind tokenKind
	text string
}

func (matcher tokenMatcher) matches(candidate token) bool {
	if matcher.kind != "" && candidate.Kind != matcher.kind {
		return false
	}

	if matcher.text != "" && candidate.Text != matcher.text {
		return false
	}

	return true
}

type tokenMatch struct {
	target token
	name   token
}

type tokenPattern struct {
	matchers    []tokenMatcher
	targetIndex int
	nameIndex   int
}

func (pattern tokenPattern) match(tokens []token, start int) (tokenMatch, bool) {
	if start < 0 || start+len(pattern.matchers) > len(tokens) {
		return tokenMatch{}, false
	}

	for offset, matcher := range pattern.matchers {
		if !matcher.matches(tokens[start+offset]) {
			return tokenMatch{}, false
		}
	}

	return tokenMatch{
		target: tokens[start+pattern.targetIndex],
		name:   tokens[start+pattern.nameIndex],
	}, true
}

var directReferencePattern = tokenPattern{
	matchers: []tokenMatcher{
		{text: openParenthesisSymbol},
		{kind: kindIdent, text: importKeyword},
		{kind: kindPath},
		{text: closeParenthesisSymbol},
		{text: fieldAccessSymbol},
		{kind: kindIdent},
	},
	targetIndex: 2,
	nameIndex:   5,
}

var doubleParenReferencePattern = tokenPattern{
	matchers: []tokenMatcher{
		{text: openParenthesisSymbol},
		{text: openParenthesisSymbol},
		{kind: kindIdent, text: importKeyword},
		{kind: kindPath},
		{text: closeParenthesisSymbol},
		{text: closeParenthesisSymbol},
		{text: fieldAccessSymbol},
		{kind: kindIdent},
	},
	targetIndex: 3,
	nameIndex:   7,
}

var aliasCallReferencePattern = tokenPattern{
	matchers: []tokenMatcher{
		{text: openParenthesisSymbol},
		{kind: kindIdent},
		{text: closeParenthesisSymbol},
		{text: fieldAccessSymbol},
		{kind: kindIdent},
	},
	targetIndex: 1,
	nameIndex:   4,
}

var aliasFieldReferencePattern = tokenPattern{
	matchers: []tokenMatcher{
		{kind: kindIdent},
		{text: fieldAccessSymbol},
		{kind: kindIdent},
	},
	targetIndex: 0,
	nameIndex:   2,
}
