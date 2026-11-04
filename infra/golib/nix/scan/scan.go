package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

type Scanner struct {
	Worktree repo.Worktree
	Files    map[string]struct{}
}

type Result struct {
	Imports map[string]struct{}
	Aliases map[string]string
	Refs    map[string]map[string]struct{}
	Issues  []string
}

func (scanner Scanner) Scan(parsedExpression string) (Result, error) {
	tokens, err := tokenize(parsedExpression)
	if err != nil {
		return Result{}, err
	}

	imported := analyzeImports(scanner.Worktree, scanner.Files, tokens)

	aliases := imported.aliasTargets()

	referenced := analyzeReferences(scanner.Worktree, scanner.Files, aliases, tokens)

	inherited := analyzeInherit(scanner.Worktree, scanner.Files, aliases, tokens)

	referenced.merge(inherited)

	return Result{
		Imports: imported.importSet(),
		Aliases: aliases,
		Refs:    map[string]map[string]struct{}(referenced),
		Issues:  imported.foundIssues(),
	}, nil
}
