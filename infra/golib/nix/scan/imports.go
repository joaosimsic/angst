package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

const (
	dynamicImportIssue = "dynamic import"
	nonPathImportIssue = "dynamic or non-path import"
)

type importScanner struct {
	worktree repo.Worktree
	files    map[string]struct{}
	findings importFindings
}

func analyzeImports(worktree repo.Worktree, files map[string]struct{}, tokens []token) importFindings {
	scanner := importScanner{
		worktree: worktree,
		files:    files,
		findings: newImportFindings(),
	}

	for start := range len(tokens) {
		scanner.scanImport(tokens, start)

		scanner.scanAlias(tokens, start)
	}

	return scanner.findings
}

func (scanner *importScanner) scanImport(tokens []token, start int) {
	keyword, ok := tokenAt(tokens, start)
	if !ok || !keyword.isIdent(importKeyword) {
		return
	}

	match, ok := directImportPattern.match(tokens, start)
	if ok {
		scanner.recordImport(match.target)
		return
	}

	if _, ok := tokenAt(tokens, start+1); !ok {
		scanner.findings.addIssue(dynamicImportIssue)
		return
	}

	scanner.findings.addIssue(nonPathImportIssue)
}

func (scanner *importScanner) recordImport(pathToken token) {
	target := relativePath(scanner.worktree, pathToken.Text)
	if _, ok := scanner.files[target]; !ok {
		return
	}

	scanner.findings.addImport(target)
}
