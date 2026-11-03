package repo

import (
	"bytes"
	"fmt"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
)

type Worktree struct {
	Root string
}

func (worktree Worktree) Abs(relativePath string) string {
	return filepath.Join(worktree.Root, filepath.FromSlash(relativePath))
}

func (worktree Worktree) Relative(absolutePath string) (string, bool) {
	if !filepath.IsAbs(absolutePath) {
		return "", false
	}

	relativePath, err := filepath.Rel(worktree.Root, absolutePath)
	if err != nil {
		return "", false
	}

	relativePath = filepath.ToSlash(relativePath)
	if relativePath == ".." || strings.HasPrefix(relativePath, "../") {
		return "", false
	}

	return relativePath, true
}

func (worktree Worktree) Under(filePath, directoryPath string) bool {
	return filePath == directoryPath || strings.HasPrefix(filePath, directoryPath+"/")
}

func (worktree Worktree) TrackedFiles(pattern string) ([]string, error) {
	cmd := exec.Command("git", "-C", worktree.Root, "ls-files", "-z", "--", pattern)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	output, err := cmd.Output()
	if err != nil {
		message := strings.TrimSpace(stderr.String())
		if message == "" {
			return nil, fmt.Errorf("git ls-files: %w", err)
		}

		return nil, fmt.Errorf("git ls-files: %s: %w", message, err)
	}

	parts := bytes.Split(output, []byte{0})
	files := make([]string, 0, len(parts))

	for _, pathPart := range parts {
		if len(pathPart) == 0 {
			continue
		}
		files = append(files, filepath.ToSlash(string(pathPart)))
	}

	slices.Sort(files)

	return files, nil
}
