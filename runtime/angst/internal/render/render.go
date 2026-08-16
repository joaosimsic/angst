package render

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"angst/internal/cmd"
	"angst/internal/paths"
)

const (
	exitUsage = 2
	exitError = 1
	exitOK    = 0
)

type output struct {
	Path string `json:"path"`
	Text string `json:"text"`
}

func defaultHost() string {
	if h := os.Getenv("NIX_DEFAULT_TARGET_HOST"); h != "" {
		return h
	}
	if h := os.Getenv("ANGST_HOST"); h != "" {
		return h
	}
	return "nixos"
}

func usage() {
	fmt.Print(`Usage:
  angst bootstrap-secrets [--host HOST]
  angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]
  angst watch  [--repo PATH] [--host HOST] [--theme THEME]
  angst projects <add|sync|status|capture|edit-env|rm> ...
  angst ssh-key <generate|verify> --scope personal|work
`)
}

func themeNames(repo string) []string {
	matches, err := filepath.Glob(filepath.Join(repo, "themes", "*.nix"))
	if err != nil {
		return nil
	}
	var names []string
	for _, f := range matches {
		if st, err := os.Stat(f); err != nil || !st.Mode().IsRegular() {
			continue
		}
		base := strings.TrimSuffix(filepath.Base(f), ".nix")
		if base == "default" || base == "schema" {
			continue
		}
		names = append(names, base)
	}
	return names
}

func reloadHooks() {
	if _, err := exec.LookPath("i3-msg"); err != nil {
		return
	}
	if os.Getenv("I3SOCK") == "" {
		return
	}
	_ = exec.Command("i3-msg", "reload").Run()
}

// Render implements `angst render`.
func Render(args []string) int {
	repoRoot := paths.RepoRoot()
	hostName := defaultHost()
	themeName := ""
	shouldReload := true

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--repo":
			if i+1 < len(args) {
				repoRoot = args[i+1]
				i++
			}
		case "--host":
			if i+1 < len(args) {
				hostName = args[i+1]
				i++
			}
		case "--theme":
			if i+1 < len(args) {
				themeName = args[i+1]
				i++
			}
		case "--reload":
			shouldReload = true
		case "--no-reload":
			shouldReload = false
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown render option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}

	if themeName == "" {
		if v, ok := paths.ConfigVal(repoRoot, hostName, "theme"); ok {
			themeName = v
		}
	}
	if themeName == "" {
		themeName = "monochrome"
	}

	if _, err := os.Stat(filepath.Join(repoRoot, "domains")); err != nil {
		fmt.Fprintf(os.Stderr, "domains directory not found under %s\n", repoRoot)
		return exitError
	}

	names := themeNames(repoRoot)
	found := false
	for _, n := range names {
		if n == themeName {
			found = true
			break
		}
	}
	if !found {
		fmt.Fprintf(os.Stderr, "Unknown theme '%s'. Available themes:\n", themeName)
		for _, n := range names {
			fmt.Fprintf(os.Stderr, "  %s\n", n)
		}
		return exitError
	}

	fmt.Println("Evaluating templates in a single optimized batch...")
	apply := fmt.Sprintf(`f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f %q))`, themeName)
	out, err := cmd.OutputRaw("nix", "eval", repoRoot+"#lib.renderDomainOutputsFor",
		"--apply", apply, "--raw")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: nix eval failed\n")
		return exitError
	}
	var outputs []output
	if err := json.Unmarshal(out, &outputs); err != nil {
		fmt.Fprintf(os.Stderr, "error: could not parse render output\n")
		return exitError
	}

	for _, o := range outputs {
		if o.Path == "" {
			continue
		}
		dest := filepath.Join(repoRoot, o.Path)
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return exitError
		}
		if err := os.WriteFile(dest, []byte(o.Text), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "error: could not write %s\n", o.Path)
			return exitError
		}
		if st, err := os.Stat(dest); err == nil {
			_ = os.Chmod(dest, st.Mode().Perm()|0o200)
		}
		fmt.Printf("rendered %s\n", o.Path)
	}

	dirs := uniqueDirs(outputs)
	for _, configDir := range dirs {
		var rel []string
		for _, o := range outputs {
			if strings.HasPrefix(o.Path, configDir+"/") {
				rel = append(rel, strings.TrimPrefix(o.Path, configDir+"/"))
			}
		}
		sort.Strings(rel)
		unique := unique(rel)
		gip := filepath.Join(repoRoot, configDir, ".gitignore")
		combined := unique
		if data, err := os.ReadFile(gip); err == nil {
			combined = paths.UniqueSorted(unique, paths.Lines(string(data)))
		}
		if err := os.WriteFile(gip, paths.JoinLines(combined), 0o644); err != nil {
			return exitError
		}
		fmt.Printf("synced %s/.gitignore\n", configDir)
	}

	if shouldReload {
		reloadHooks()
	}
	return exitOK
}

func uniqueDirs(outputs []output) []string {
	seen := map[string]bool{}
	var out []string
	for _, o := range outputs {
		d := paths.SubDir(o.Path, 4)
		if !seen[d] {
			seen[d] = true
			out = append(out, d)
		}
	}
	sort.Strings(out)
	return out
}

func unique(items []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, it := range items {
		if !seen[it] {
			seen[it] = true
			out = append(out, it)
		}
	}
	return out
}

// Watch implements `angst watch`.
func Watch(args []string) int {
	repoRoot := paths.RepoRoot()
	hostName := defaultHost()
	themeName := os.Getenv("ANGST_THEME")

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--repo":
			if i+1 < len(args) {
				repoRoot = args[i+1]
				i++
			}
		case "--host":
			if i+1 < len(args) {
				hostName = args[i+1]
				i++
			}
		case "--theme":
			if i+1 < len(args) {
				themeName = args[i+1]
				i++
			}
		case "-h", "--help":
			usage()
			return exitOK
		default:
			fmt.Fprintf(os.Stderr, "unknown watch option: %s\n", args[i])
			usage()
			return exitUsage
		}
	}

	selfArgs := []string{"render", "--repo", repoRoot, "--host", hostName, "--reload"}
	if themeName != "" {
		selfArgs = append(selfArgs, "--theme", themeName)
	}

	watchPath := filepath.Join(repoRoot, "hosts", hostName)
	if resolved, ok := paths.FindHostConfigDir(repoRoot, hostName); ok {
		watchPath = resolved
	}

	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: cannot determine own executable")
		return exitError
	}
	watchexec, err := exec.LookPath("watchexec")
	if err != nil {
		fmt.Fprintln(os.Stderr, "error: watchexec not found in PATH")
		return exitError
	}
	wargs := []string{
		"--watch", filepath.Join(repoRoot, "themes"),
		"--watch", filepath.Join(repoRoot, "domains"),
		"--watch", watchPath,
		"--", exe,
	}
	wargs = append(wargs, selfArgs...)
	_ = exec.Command(watchexec, wargs...).Run()
	return exitOK
}
