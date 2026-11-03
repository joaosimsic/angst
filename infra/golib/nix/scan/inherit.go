package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

type inheritScanner struct {
	worktree repo.Worktree
	files    map[string]struct{}
	aliases  map[string]string
	output   referenceSet
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
	if !tokens[start].isIdent("inherit") {
		return
	}

	target, next, ok := analyzer.inheritTarget(tokens, start+1)
	if !ok {
		return
	}

	analyzer.addInheritRefs(tokens, next, target)
}

func (analyzer inheritScanner) inheritTarget(tokens []token, start int) (string, int, bool) {
	if start >= len(tokens) || tokens[start].Text != "(" {
		return "", 0, false
	}
	start++

	if start >= len(tokens) {
		return "", 0, false
	}

	if tokens[start].Kind == kindIdent && start+1 < len(tokens) && tokens[start+1].Text == ")" {
		target := analyzer.aliases[tokens[start].Text]

		return target, start + 2, target != ""
	}

	if tokens[start].Text == "(" && start+3 < len(tokens) && tokens[start+1].isIdent("import") && tokens[start+2].Kind == kindPath && tokens[start+3].Text == ")" {
		target := relativePath(analyzer.worktree, tokens[start+2].Text)
		next := start + 4
		if next < len(tokens) && tokens[next].Text == ")" {
			next++
		}

		return target, next, target != ""
	}

	if tokens[start].isIdent("import") && start+1 < len(tokens) && tokens[start+1].Kind == kindPath {
		target := relativePath(analyzer.worktree, tokens[start+1].Text)
		next := start + 2
		if next < len(tokens) && tokens[next].Text == ")" {
			next++
		}

		return target, next, target != ""
	}

	return "", 0, false
}

func (analyzer inheritScanner) addInheritRefs(tokens []token, start int, target string) {
	for start < len(tokens) && tokens[start].Text != ";" {
		if tokens[start].Kind == kindIdent {
			analyzer.output.add(analyzer.files, target, tokens[start].Text)
		}
		start++
	}
}
