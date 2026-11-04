package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

type inheritScanner struct {
	worktree repo.Worktree
	files    map[string]struct{}
	aliases  map[string]string
	output   referenceSet
}

var inheritAliasPattern = tokenPattern{
	matchers: []tokenMatcher{
		{kind: kindIdent},
		{text: closeParenthesisSymbol},
	},
	targetIndex: 0,
	nameIndex:   0,
}

func analyzeInherit(worktree repo.Worktree, files map[string]struct{}, aliases map[string]string, tokens []token) referenceSet {
	analyzer := inheritScanner{
		worktree: worktree,
		files:    files,
		aliases:  aliases,
		output:   newReferenceSet(),
	}

	for i := range len(tokens) {
		analyzer.scanInherit(tokens, i)
	}

	return analyzer.output
}

func (analyzer inheritScanner) scanInherit(tokens []token, start int) {
	keyword, ok := tokenAt(tokens, start)
	if !ok || !keyword.isIdent(inheritKeyword) {
		return
	}

	target, next, ok := analyzer.inheritTarget(tokens, start+1)
	if !ok {
		return
	}

	analyzer.addInheritRefs(tokens, next, target)
}

func (analyzer inheritScanner) inheritTarget(tokens []token, start int) (string, int, bool) {
	opening, ok := tokenAt(tokens, start)
	if !ok || !opening.isSymbol(openParenthesisSymbol) {
		return "", 0, false
	}

	start++

	if match, ok := inheritAliasPattern.match(tokens, start); ok {
		target := analyzer.aliases[match.name.Text]

		return target, start + len(inheritAliasPattern.matchers), target != ""
	}

	imported, ok := matchImportTarget(tokens, start)
	if !ok {
		return "", 0, false
	}

	target := relativePath(analyzer.worktree, imported.pathToken.Text)
	next := start + imported.consumed
	if next < len(tokens) && tokens[next].isSymbol(closeParenthesisSymbol) {
		next++
	}

	return target, next, target != ""
}

func (analyzer inheritScanner) addInheritRefs(tokens []token, start int, target string) {
	for start < len(tokens) && !tokens[start].isSymbol(statementTerminatorSymbol) {
		if tokens[start].Kind == kindIdent {
			analyzer.output.add(analyzer.files, target, tokens[start].Text)
		}

		start++
	}
}
