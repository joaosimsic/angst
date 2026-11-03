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

type referenceMatch struct {
	target token
	name   token
}

type referencePattern struct {
	matchers    []tokenMatcher
	targetIndex int
	nameIndex   int
}

func (pattern referencePattern) match(tokens []token, start int) (referenceMatch, bool) {
	if start+len(pattern.matchers) > len(tokens) {
		return referenceMatch{}, false
	}

	for offset, matcher := range pattern.matchers {
		if !matcher.matches(tokens[start+offset]) {
			return referenceMatch{}, false
		}
	}

	return referenceMatch{
		target: tokens[start+pattern.targetIndex],
		name:   tokens[start+pattern.nameIndex],
	}, true
}

var directReferencePattern = referencePattern{
	matchers: []tokenMatcher{
		{text: "("},
		{kind: kindIdent, text: "import"},
		{kind: kindPath},
		{text: ")"},
		{text: "."},
		{kind: kindIdent},
	},
	targetIndex: 2,
	nameIndex:   5,
}

var doubleParenReferencePattern = referencePattern{
	matchers: []tokenMatcher{
		{text: "("},
		{text: "("},
		{kind: kindIdent, text: "import"},
		{kind: kindPath},
		{text: ")"},
		{text: ")"},
		{text: "."},
		{kind: kindIdent},
	},
	targetIndex: 3,
	nameIndex:   7,
}

var aliasCallReferencePattern = referencePattern{
	matchers: []tokenMatcher{
		{text: "("},
		{kind: kindIdent},
		{text: ")"},
		{text: "."},
		{kind: kindIdent},
	},
	targetIndex: 1,
	nameIndex:   4,
}

var aliasFieldReferencePattern = referencePattern{
	matchers: []tokenMatcher{
		{kind: kindIdent},
		{text: "."},
		{kind: kindIdent},
	},
	targetIndex: 0,
	nameIndex:   2,
}
