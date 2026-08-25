package analyze

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

func sectionDeadCode() string {
	lines := []string{mdSection(23, "Dead Code")}
	if !hasCmd("deadnix") {
		lines = append(lines, "> `deadnix` not found. Install with `nix shell nixpkgs#deadnix`.\n")
		return strings.Join(lines, "\n")
	}
	rc, out, _ := runExec([]string{"deadnix", ".", "--quiet", "--no-lambda-pattern-names"}, 30*time.Second)
	if rc > 1 {
		lines = append(lines, "_(deadnix encountered an error)_")
	} else if strings.TrimSpace(out) != "" {
		lines = append(lines, mdCode(strings.TrimSpace(out)))
	} else {
		lines = append(lines, "✓ No dead code detected.")
	}
	return strings.Join(lines, "\n")
}

func sectionAntiPatterns() string {
	lines := []string{mdSection(24, "Anti-Patterns (statix)")}
	if !hasCmd("statix") {
		lines = append(lines, "> `statix` not found. Install with `nix shell nixpkgs#statix`.\n")
		return strings.Join(lines, "\n")
	}
	rc, out, _ := runExec([]string{"statix", "check", "."}, 30*time.Second)
	if rc > 1 {
		lines = append(lines, "_(statix encountered an error)_")
	} else if strings.TrimSpace(out) != "" {
		lines = append(lines, mdCode(strings.TrimSpace(out)))
	} else {
		lines = append(lines, "✓ No anti-patterns detected.")
	}
	return strings.Join(lines, "\n")
}

func timed(label string, cmd []string, timeout time.Duration) []any {
	start := time.Now()
	rc, _, err := runExec(cmd, timeout)
	elapsed := time.Since(start).Seconds()
	status := "✓"
	if rc != 0 {
		status = "✗"
	}
	if strings.Contains(err, "timed out") {
		status = "⚠"
		elapsed = timeout.Seconds()
	}
	return []any{label, status, fmt.Sprintf("%.2fs", elapsed)}
}

func sectionEvalCost(noEvalCost bool) string {
	lines := []string{mdSection(25, "Evaluation Cost")}
	if noEvalCost {
		lines = append(lines, "> Skipped (`--no-eval-cost`)\n")
		return strings.Join(lines, "\n")
	}
	lines = append(lines, mdSubsection("Evaluation (attribute resolution)"))
	evalTrials := [][]any{
		timed("nix flake show", []string{"nix", "flake", "show"}, 120*time.Second),
	}
	for _, attr := range []string{"packages.x86_64-linux", "apps.x86_64-linux", "checks.x86_64-linux"} {
		evalTrials = append(evalTrials, timed(attr, []string{
			"nix", "eval", "." + "#" + attr, "--apply", "builtins.attrNames",
		}, 60*time.Second))
	}
	lines = append(lines, mdTable([]string{"Command", "Result", "Time"}, evalTrials))

	lines = append(lines, mdSubsection("Build (realisation)"))
	buildTrials := [][]any{
		timed("nix flake check", []string{"nix", "flake", "check", "--no-build"}, 120*time.Second),
	}
	lines = append(lines, mdTable([]string{"Command", "Result", "Time"}, buildTrials))
	return strings.Join(lines, "\n")
}

func sectionTechDebt() string {
	lines := []string{mdSection(26, "Technical Debt Score")}
	checks := [][3]any{}

	files := findNixFiles()
	fanOut, _ := parseImportsFromTree(files)
	hasCycle := false
	visited := map[string]bool{}
	stack := map[string]bool{}
	var hasCycleDFS func(node string) bool
	hasCycleDFS = func(node string) bool {
		if stack[node] {
			return true
		}
		if visited[node] {
			return false
		}
		stack[node] = true
		for _, dep := range fanOut[node] {
			if hasCycleDFS(dep) {
				return true
			}
		}
		delete(stack, node)
		visited[node] = true
		return false
	}
	for _, f := range files {
		if hasCycleDFS(f) {
			hasCycle = true
			break
		}
	}
	checks = append(checks, [3]any{"Architecture", "No cyclic imports", !hasCycle})

	parseEnvFiles := len(rgList("parseEnv", false))
	checks = append(checks, [3]any{"Architecture", fmt.Sprintf("parseEnv imported from %d files", parseEnvFiles), parseEnvFiles <= 4})

	x86Files := len(rgList("x86_64-linux", false))
	checks = append(checks, [3]any{"Portability", fmt.Sprintf("%d architecture-specific literals (x86_64-linux)", x86Files), x86Files <= 5})

	repoFiles := len(rgList("proj/angst", false))
	checks = append(checks, [3]any{"Portability", fmt.Sprintf("%d repository path literals (proj/angst)", repoFiles), repoFiles <= 3})

	storeFiles := len(rgList("/nix/store", false))
	checks = append(checks, [3]any{"Portability", fmt.Sprintf("%d files reference /nix/store", storeFiles), storeFiles <= 1})

	allDomainsHaveDefault := true
	domainsPath := filepath.Join(repoRoot(), "domains")
	if dirExists(domainsPath) {
		for _, cat := range sortedDirs(domainsPath) {
			catPath := filepath.Join(domainsPath, cat)
			if !dirExists(catPath) {
				continue
			}
			for _, d := range sortedDirs(catPath) {
				if dirExists(filepath.Join(catPath, d)) && !fileExists(filepath.Join(catPath, d, "default.nix")) {
					allDomainsHaveDefault = false
				}
			}
		}
	}
	checks = append(checks, [3]any{"Configuration", "All domains have default.nix", allDomainsHaveDefault})

	statixOK := true
	if hasCmd("statix") {
		rc, _, _ := runExec([]string{"statix", "check", "."}, 30*time.Second)
		statixOK = rc == 0
	}
	checks = append(checks, [3]any{"Evaluation", "Statix clean", statixOK})

	deadnixOK := true
	if hasCmd("deadnix") {
		rc, _, _ := runExec([]string{"deadnix", ".", "--quiet", "--no-lambda-pattern-names"}, 30*time.Second)
		deadnixOK = rc == 0
	}
	checks = append(checks, [3]any{"Evaluation", "No dead code (deadnix clean)", deadnixOK})

	categories := map[string][][2]any{}
	for _, c := range checks {
		cat := c[0].(string)
		desc := c[1].(string)
		ok := c[2].(bool)
		categories[cat] = append(categories[cat], [2]any{desc, ok})
	}
	for _, cat := range []string{"Architecture", "Portability", "Configuration", "Evaluation"} {
		items, ok := categories[cat]
		if !ok {
			continue
		}
		lines = append(lines, fmt.Sprintf("\n### %s\n", cat))
		for _, it := range items {
			prefix := "✓"
			if !it[1].(bool) {
				prefix = "⚠"
			}
			lines = append(lines, fmt.Sprintf("- %s %s", prefix, it[0].(string)))
		}
	}
	return strings.Join(lines, "\n")
}
