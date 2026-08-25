package analyze

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"angst/internal/paths"
)

var rgExcludes = []string{
	"-g", "!.git",
	"-g", "!result",
}

func repoRoot() string { return paths.RepoRoot() }

func hasCmd(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// runExec runs a command in the repo root and returns (rc, stdout, stderr).
func runExec(args []string, timeout time.Duration) (int, string, string) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Dir = repoRoot()
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errb
	err := cmd.Run()
	rc := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			rc = ee.ExitCode()
		} else {
			rc = -1
		}
	}
	return rc, out.String(), errb.String()
}

func rgExec(args []string, timeout time.Duration) (int, string, error) {
	full := append([]string{}, args...)
	full = append(full, "--type", "nix")
	full = append(full, rgExcludes...)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "rg", full...)
	cmd.Dir = repoRoot()
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errb
	err := cmd.Run()
	rc := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			rc = ee.ExitCode()
		} else {
			rc = -1
		}
	}
	return rc, out.String(), err
}

// rgCount returns the total number of matches for pat across .nix files.
func rgCount(pat string, fixed bool) int {
	args := []string{}
	if fixed {
		args = append(args, "-F")
	}
	args = append(args, "-c", pat)
	rc, out, _ := rgExec(args, 15*time.Second)
	if rc != 0 && rc != 1 {
		return 0
	}
	total := 0
	for _, l := range strings.Split(out, "\n") {
		l = strings.TrimSpace(l)
		if l == "" {
			continue
		}
		if idx := strings.LastIndex(l, ":"); idx >= 0 {
			n, err := strconv.Atoi(strings.TrimSpace(l[idx+1:]))
			if err == nil {
				total += n
			}
		}
	}
	return total
}

// rgList returns the files that contain pat.
func rgList(pat string, fixed bool) []string {
	args := []string{}
	if fixed {
		args = append(args, "-F")
	}
	args = append(args, "-l", pat)
	rc, out, _ := rgExec(args, 15*time.Second)
	if rc != 0 && rc != 1 {
		return nil
	}
	var files []string
	for _, l := range strings.Split(out, "\n") {
		l = strings.TrimSpace(l)
		if l != "" {
			files = append(files, l)
		}
	}
	return files
}

// rgOnly returns the matching substrings (with -o).
func rgOnly(pat string) []string {
	rc, out, _ := rgExec([]string{"-o", "--no-filename", pat}, 15*time.Second)
	if rc != 0 && rc != 1 {
		return nil
	}
	var res []string
	for _, l := range strings.Split(out, "\n") {
		l = strings.TrimSpace(l)
		if l != "" {
			res = append(res, l)
		}
	}
	return res
}

func readNix(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(b)
}

func findNixFiles() []string {
	root := repoRoot()
	var out []string
	_ = filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			base := filepath.Base(p)
			if base == ".git" || base == "result" {
				return filepath.SkipDir
			}
			rel, _ := filepath.Rel(root, p)
			parts := strings.Split(rel, string(filepath.Separator))
			if len(parts) >= 2 && parts[0] == "tools" && (parts[1] == "vm" || parts[1] == "shell") {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(p) != ".nix" {
			return nil
		}
		out = append(out, p)
		return nil
	})
	return out
}

func nixEvalAttrNames(attr string) []string {
	rc, out, _ := runExec([]string{
		"nix", "eval", "." + "#" + attr, "--no-warn-dirty",
		"--apply", "builtins.attrNames", "--json",
	}, 60*time.Second)
	if rc != 0 {
		return nil
	}
	var names []string
	if err := json.Unmarshal([]byte(out), &names); err != nil {
		return nil
	}
	return names
}

func gitLog(patterns []string, since string) []string {
	args := []string{"git", "log", "--oneline", "--since=" + since, "--name-only", "--"}
	args = append(args, patterns...)
	rc, out, _ := runExec(args, 30*time.Second)
	if rc != 0 {
		return nil
	}
	var res []string
	for _, l := range strings.Split(out, "\n") {
		l = strings.TrimSpace(l)
		if l != "" {
			res = append(res, l)
		}
	}
	return res
}

// ---- markdown helpers ----

func mdEscape(s string) string { return strings.ReplaceAll(s, "|", "\\|") }

func mdSection(n int, title string) string {
	return fmt.Sprintf("\n## %d. %s\n", n, title)
}

func mdSubsection(title string) string {
	return fmt.Sprintf("\n### %s\n", title)
}

func mdCode(text string) string {
	return "```\n" + text + "\n```"
}

func mdTable(headers []string, rows [][]any) string {
	lines := []string{}
	lines = append(lines, "| "+strings.Join(mapEscape(headers), " | ")+" |")
	lines = append(lines, "|"+strings.Repeat("---|", len(headers)))
	for _, row := range rows {
		cells := make([]string, len(row))
		for i, c := range row {
			cells[i] = mdEscape(fmt.Sprintf("%v", c))
		}
		lines = append(lines, "| "+strings.Join(cells, " | ")+" |")
	}
	return strings.Join(lines, "\n")
}

func mapEscape(in []string) []string {
	out := make([]string, len(in))
	for i, s := range in {
		out[i] = mdEscape(s)
	}
	return out
}

func relOf(abs string) string {
	rel, err := filepath.Rel(repoRoot(), abs)
	if err != nil {
		return abs
	}
	return rel
}

func fileExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir()
}

func dirExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

func sortedKeysString(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
