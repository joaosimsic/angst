package scan

import "github.com/joaosimsic/angst/infra/golib/repo"

func relativePath(worktree repo.Worktree, absolutePath string) string {
	resolvedPath, ok := worktree.Relative(absolutePath)
	if !ok {
		return ""
	}

	return resolvedPath
}
