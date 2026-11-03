package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

type referenceScanner struct {
	worktree repo.Worktree
	files    map[string]struct{}
	aliases  map[string]string
	output   referenceSet
}

func analyzeReferences(worktree repo.Worktree, files map[string]struct{}, aliases map[string]string, tokens []token) referenceSet {
	analyzer := referenceScanner{
		worktree: worktree,
		files:    files,
		aliases:  aliases,
		output:   newReferenceSet(),
	}

	for i := range len(tokens) {
		analyzer.scanDirectReference(tokens, i)

		analyzer.scanDoubleParenReference(tokens, i)

		analyzer.scanAliasCallReference(tokens, i)

		analyzer.scanAliasFieldReference(tokens, i)
	}

	return analyzer.output
}

func (analyzer referenceScanner) scanDirectReference(tokens []token, start int) {
	match, ok := directReferencePattern.match(tokens, start)
	if !ok {
		return
	}

	analyzer.output.add(analyzer.files, relativePath(analyzer.worktree, match.target.Text), match.name.Text)
}

func (analyzer referenceScanner) scanDoubleParenReference(tokens []token, start int) {
	match, ok := doubleParenReferencePattern.match(tokens, start)
	if !ok {
		return
	}

	analyzer.output.add(analyzer.files, relativePath(analyzer.worktree, match.target.Text), match.name.Text)
}

func (analyzer referenceScanner) scanAliasCallReference(tokens []token, start int) {
	match, ok := aliasCallReferencePattern.match(tokens, start)
	if !ok {
		return
	}

	target, ok := analyzer.aliases[match.target.Text]
	if !ok {
		return
	}

	analyzer.output.add(analyzer.files, target, match.name.Text)
}

func (analyzer referenceScanner) scanAliasFieldReference(tokens []token, start int) {
	match, ok := aliasFieldReferencePattern.match(tokens, start)
	if !ok {
		return
	}

	target, ok := analyzer.aliases[match.target.Text]
	if !ok {
		return
	}

	analyzer.output.add(analyzer.files, target, match.name.Text)
}
