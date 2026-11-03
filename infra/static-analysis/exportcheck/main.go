package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/joaosimsic/angst/infra/golib/nix"
	"github.com/joaosimsic/angst/infra/golib/nix/scan"
	"github.com/joaosimsic/angst/infra/golib/repo"
)

func main() {
	root := "."
	if len(os.Args) > 1 {
		root = os.Args[1]
	}

	absoluteRoot, err := filepath.Abs(root)
	if err != nil {
		fail(err)
	}

	worktree := repo.Worktree{Root: absoluteRoot}
	files, err := worktree.TrackedFiles("*.nix")
	if err != nil {
		fail(err)
	}

	trackedFiles := make(map[string]struct{}, len(files))

	for _, file := range files {
		trackedFiles[file] = struct{}{}
	}

	engine := nix.Engine{Worktree: worktree}
	scanner := scan.Scanner{Worktree: worktree, Files: trackedFiles}

	infos := make(map[string]*fileInfo, len(files))

	for _, file := range files {
		info := &fileInfo{
			Path:        file,
			IsTest:      isTestPath(file),
			Imports:     map[string]struct{}{},
			AliasTarget: map[string]string{},
			Refs:        map[string]map[string]struct{}{},
		}

		infos[file] = info

		if info.IsTest {
			continue
		}

		parsedExpression, err := engine.ParseExpression(file)
		if err != nil {
			fail(fmt.Errorf("%s: %w", file, err))
		}

		exports, err := engine.Exports(file)
		if err != nil {
			fail(fmt.Errorf("%s: %w", file, err))
		}

		info.Kind = exports.Kind
		info.Exports = exports.Names

		result, err := scanner.Scan(parsedExpression)
		if err != nil {
			fail(fmt.Errorf("%s: %w", file, err))
		}

		info.Imports = result.Imports

		info.AliasTarget = result.Aliases

		info.Refs = result.Refs

		info.Issues = result.Issues
	}

	for _, info := range infos {
		info.ModuleRoot = findModuleRoot(info.Path, trackedFiles)
	}

	violations := analyze(worktree, infos)
	if len(violations) == 0 {
		return
	}

	for _, foundViolation := range violations {
		fmt.Fprintf(os.Stderr, "%s: %s export `%s`: %s\n", foundViolation.Path, foundViolation.Scope, foundViolation.Name, foundViolation.Message)
	}

	os.Exit(1)
}

func fail(err error) {
	fmt.Fprintf(os.Stderr, "exportcheck: %v\n", err)
	os.Exit(1)
}
