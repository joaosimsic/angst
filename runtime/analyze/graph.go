package analyze

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var importRe = regexp.MustCompile(
	`import\s+\(?\s*(\.\.?/[^'"\s;)]+)\.nix|import\s+\(?\s*["'](\.\.?/[^"'\s;)]+)["']`,
)

func parseImports(text, baseDir string) []string {
	var out []string
	for _, m := range importRe.FindAllStringSubmatch(text, -1) {
		raw := m[1]
		if raw == "" {
			raw = m[2]
		}
		raw = strings.TrimRight(raw, "/")
		if !strings.HasPrefix(raw, ".") {
			continue
		}
		full := filepath.Clean(filepath.Join(baseDir, raw))
		for _, candidate := range []string{full, full + ".nix"} {
			if filepath.Ext(candidate) != ".nix" {
				continue
			}
			if _, err := os.Stat(candidate); err == nil {
				out = append(out, candidate)
				break
			}
		}
	}
	return out
}

func parseImportsFromTree(files []string) (map[string][]string, map[string]int) {
	fanOut := map[string][]string{}
	fanIn := map[string]int{}
	for _, f := range files {
		text := readNix(f)
		deps := parseImports(text, filepath.Dir(f))
		fanOut[f] = deps
		for _, d := range deps {
			fanIn[d]++
		}
	}
	return fanOut, fanIn
}

func transitiveDependents(fanOut map[string][]string) map[string]int {
	reverse := map[string]map[string]bool{}
	allNodes := map[string]bool{}
	for src, deps := range fanOut {
		allNodes[src] = true
		for _, d := range deps {
			if reverse[d] == nil {
				reverse[d] = map[string]bool{}
			}
			reverse[d][src] = true
			allNodes[d] = true
		}
	}
	memo := map[string]int{}
	var closure func(node string, visiting map[string]bool) int
	closure = func(node string, visiting map[string]bool) int {
		if v, ok := memo[node]; ok {
			return v
		}
		if visiting[node] {
			return 0
		}
		visiting[node] = true
		result := 0
		for dep := range reverse[node] {
			result++
			result += closure(dep, visiting)
		}
		memo[node] = result
		delete(visiting, node)
		return result
	}
	out := map[string]int{}
	for node := range allNodes {
		out[node] = closure(node, map[string]bool{})
	}
	return out
}

func buildImportTree(root string, fanOut map[string][]string) string {
	var lines []string
	lines = append(lines, relOf(root))
	visited := map[string]bool{}
	deps := fanOut[root]
	for i, dep := range deps {
		lines = append(lines, renderTreeLines(dep, fanOut, "", i == len(deps)-1, visited)...)
	}
	return strings.Join(lines, "\n")
}

func renderTreeLines(node string, fanOut map[string][]string, prefix string, isLast bool, visited map[string]bool) []string {
	lines := []string{}
	marker := "└── "
	if !isLast {
		marker = "├── "
	}
	lines = append(lines, prefix+marker+relOf(node))
	if visited[node] {
		lines = append(lines, prefix+childPad(isLast)+"(cycle)")
		return lines
	}
	visited[node] = true
	deps := fanOut[node]
	childPrefix := prefix + childPad(isLast)
	for i, dep := range deps {
		lines = append(lines, renderTreeLines(dep, fanOut, childPrefix, i == len(deps)-1, visited)...)
	}
	delete(visited, node)
	return lines
}

func childPad(isLast bool) string {
	if isLast {
		return "    "
	}
	return "│   "
}

func buildMermaidGraph(fanOut map[string][]string) string {
	edges := []string{}
	seen := map[[2]string]bool{}
	nodeIDs := map[string]string{}
	nextID := 0
	var nid func(p string) string
	nid = func(p string) string {
		if id, ok := nodeIDs[p]; ok {
			return id
		}
		id := fmt.Sprintf("n%d", nextID)
		nextID++
		nodeIDs[p] = id
		return id
	}
	var walk func(node string, v map[string]bool)
	walk = func(node string, v map[string]bool) {
		if v[node] {
			return
		}
		v[node] = true
		for _, dep := range fanOut[node] {
			if !seen[[2]string{node, dep}] {
				seen[[2]string{node, dep}] = true
				edges = append(edges, fmt.Sprintf("    %s[\"%s\"] --> %s[\"%s\"]",
					nid(node), relOf(node), nid(dep), relOf(dep)))
			}
			walk(dep, v)
		}
	}
	walk(filepath.Join(repoRoot(), "flake.nix"), map[string]bool{})
	lines := []string{"```mermaid", "flowchart LR"}
	lines = append(lines, edges...)
	lines = append(lines, "```")
	return strings.Join(lines, "\n")
}

var layerOrder = []string{
	"flake.nix", "lib", "common", "domains", "themes", "toolchains", "hosts", "runtime",
}

func fileLayer(abs string) int {
	rel := relOf(abs)
	if rel == "flake.nix" {
		return 0
	}
	parts := strings.Split(rel, string(filepath.Separator))
	if len(parts) > 0 {
		for i, l := range layerOrder {
			if parts[0] == l {
				return i
			}
		}
	}
	return 5
}

func checkLayerViolations(fanOut map[string][]string) [][2]string {
	var violations [][2]string
	for src, deps := range fanOut {
		if relOf(src) == "flake.nix" {
			continue
		}
		srcLayer := fileLayer(src)
		for _, dep := range deps {
			if relOf(dep) == "flake.nix" {
				continue
			}
			if srcLayer < fileLayer(dep) {
				violations = append(violations, [2]string{src, dep})
			}
		}
	}
	return violations
}

type importPair struct {
	depth int
	path  []string
}

func deepestImportPath(root string, fanOut map[string][]string) (int, []string) {
	memo := map[string]importPair{}
	var dfs func(node string, visiting map[string]bool) importPair
	dfs = func(node string, visiting map[string]bool) importPair {
		if v, ok := memo[node]; ok {
			return v
		}
		if visiting[node] {
			return importPair{0, nil}
		}
		visiting[node] = true
		best := importPair{0, nil}
		for _, dep := range fanOut[node] {
			p := dfs(dep, visiting)
			if p.depth+1 > best.depth {
				best = importPair{p.depth + 1, append([]string{dep}, p.path...)}
			}
		}
		memo[node] = best
		delete(visiting, node)
		return best
	}
	r := dfs(root, map[string]bool{})
	return r.depth, r.path
}
