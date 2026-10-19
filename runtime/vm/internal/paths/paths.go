package paths

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

func RepoRoot() string {
	if root := os.Getenv("ANGST_REPO_ROOT"); root != "" {
		return root
	}
	if out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output(); err == nil {
		if root := strings.TrimSpace(string(out)); root != "" {
			return root
		}
	}
	if root := os.Getenv("ANGST_REPO_FALLBACK"); root != "" {
		return root
	}
	if cwd, err := os.Getwd(); err == nil {
		return cwd
	}
	return "."
}

func FindHostConfigDir(repo, host string) (string, bool) {
	domains, err := os.ReadDir(filepath.Join(repo, "hosts"))
	if err != nil {
		return "", false
	}
	for _, d := range domains {
		if !d.IsDir() {
			continue
		}
		candidate := filepath.Join(repo, "hosts", d.Name(), host)
		if isRegular(candidate, "default.nix") {
			return candidate, true
		}
	}
	candidate := filepath.Join(repo, "hosts", host)
	if isRegular(candidate, "default.nix") {
		return candidate, true
	}
	return "", false
}

func isRegular(dir, name string) bool {
	st, err := os.Stat(filepath.Join(dir, name))
	return err == nil && st.Mode().IsRegular()
}

func ConfigVal(repo, host, key string) (string, bool) {
	dir, ok := FindHostConfigDir(repo, host)
	if !ok {
		return "", false
	}
	apply := fmt.Sprintf("x: x.%s or null", key)
	out, err := exec.Command(
		"nix", "eval", "--file", filepath.Join(dir, "default.nix"),
		"--raw", "--apply", apply,
	).Output()
	if err != nil {
		return "", false
	}
	return strings.TrimRight(string(out), "\n"), true
}

func SubDir(p string, n int) string {
	parts := strings.Split(p, "/")
	if len(parts) > n {
		parts = parts[:n]
	}
	return strings.Join(parts, "/")
}

func TrimPrefixIf(s, prefix string) string {
	if strings.HasPrefix(s, prefix) {
		return strings.TrimPrefix(s, prefix)
	}
	return s
}

func Lines(s string) []string {
	trimmed := strings.TrimRight(s, "\n")
	if trimmed == "" {
		return nil
	}
	return strings.Split(trimmed, "\n")
}

func UniqueSorted(groups ...[]string) []string {
	seen := make(map[string]bool, 0)
	var all []string
	for _, g := range groups {
		for _, l := range g {
			if !seen[l] {
				seen[l] = true
				all = append(all, l)
			}
		}
	}
	sort.Strings(all)
	return all
}

func JoinLines(lines []string) []byte {
	return []byte(strings.Join(lines, "\n") + "\n")
}
