package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

type importAnalysis struct {
	Imports map[string]struct{}
	Aliases map[string]string
	Issues  []string
}

func analyzeImports(worktree repo.Worktree, files map[string]struct{}, tokens []token) importAnalysis {
	result := importAnalysis{
		Imports: map[string]struct{}{},
		Aliases: map[string]string{},
	}

	for i := range len(tokens) {
		scanImport(worktree, files, tokens, i, &result)
	}

	for i := 0; i+3 < len(tokens); i++ {
		scanAlias(worktree, tokens, i, &result)
	}

	return result
}

func scanImport(worktree repo.Worktree, files map[string]struct{}, tokens []token, start int, result *importAnalysis) {
	if !tokens[start].isIdent("import") {
		return
	}
	if start+1 >= len(tokens) {
		result.Issues = append(result.Issues, "dynamic import")
		return
	}
	if tokens[start+1].Kind != kindPath {
		result.Issues = append(result.Issues, "dynamic or non-path import")
		return
	}

	target := relativePath(worktree, tokens[start+1].Text)
	if target == "" {
		return
	}
	if _, ok := files[target]; ok {
		result.Imports[target] = struct{}{}
	}
}

func scanAlias(worktree repo.Worktree, tokens []token, start int, result *importAnalysis) {
	if tokens[start].Kind != kindIdent || tokens[start].Text == "import" {
		return
	}
	if start > 0 && tokens[start-1].Text == "." {
		return
	}
	if tokens[start+1].Text != "=" {
		return
	}

	importStart := start + 2
	if importStart+3 < len(tokens) && tokens[importStart].Text == "(" && tokens[importStart+1].isIdent("import") && tokens[importStart+2].Kind == kindPath && tokens[importStart+3].Text == ")" {
		result.Aliases[tokens[start].Text] = relativePath(worktree, tokens[importStart+2].Text)
	}
}
