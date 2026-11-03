package main

import (
	"cmp"
	"maps"
	"slices"

	"github.com/joaosimsic/angst/infra/golib/repo"
)

type analyzer struct {
	worktree repo.Worktree
	infos    map[string]*fileInfo
	paths    []string
}

func analyze(worktree repo.Worktree, infos map[string]*fileInfo) []violation {
	exportAnalyzer := analyzer{
		worktree: worktree,
		infos:    infos,
		paths:    slices.Sorted(maps.Keys(infos)),
	}

	violations := slices.Concat(exportAnalyzer.exportViolations(), exportAnalyzer.privateImportViolations())

	slices.SortFunc(violations, compareViolations)

	return slices.Compact(violations)
}

func compareViolations(left, right violation) int {
	return cmp.Or(
		cmp.Compare(left.Path, right.Path),
		cmp.Compare(left.Scope, right.Scope),
		cmp.Compare(left.Name, right.Name),
	)
}
