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

	referenced := analyzeReferences(scanner.Worktree, scanner.Files, imported.Aliases, tokens)

	inherited := analyzeInherit(scanner.Worktree, scanner.Files, imported.Aliases, tokens)

	referenced.merge(inherited)

	return Result{
		Imports: imported.Imports,
		Aliases: imported.Aliases,
		Refs:    map[string]map[string]struct{}(referenced),
		Issues:  imported.Issues,
	}, nil
}
