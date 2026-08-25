package analyze

import (
	"fmt"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type kv struct {
	key string
	val int
}

func sortedByValDesc(m map[string]int) []kv {
	var s []kv
	for k, v := range m {
		s = append(s, kv{k, v})
	}
	sort.Slice(s, func(i, j int) bool { return s[i].val > s[j].val })
	return s
}

func sortedByLenDesc(m map[string][]string) []kv {
	var s []kv
	for k, v := range m {
		s = append(s, kv{k, len(v)})
	}
	sort.Slice(s, func(i, j int) bool { return s[i].val > s[j].val })
	return s
}

func sectionDependencyFan() string {
	lines := []string{mdSection(7, "Dependency Fan-in / Fan-out")}
	files := findNixFiles()
	fanOut, fanIn := parseImportsFromTree(files)
	trans := transitiveDependents(fanOut)

	lines = append(lines, mdSubsection("Most imported modules (fan-in)"))
	fiRows := [][]any{}
	for _, e := range sortedByValDesc(fanIn) {
		if len(fiRows) >= 15 {
			break
		}
		fiRows = append(fiRows, []any{strconv.Itoa(e.val), strconv.Itoa(trans[e.key]), relOf(e.key)})
	}
	lines = append(lines, mdTable([]string{"Direct", "Transitive", "File"}, fiRows))

	lines = append(lines, mdSubsection("Largest dependency fan-out"))
	foRows := [][]any{}
	for _, e := range sortedByLenDesc(fanOut) {
		if len(foRows) >= 15 {
			break
		}
		foRows = append(foRows, []any{strconv.Itoa(e.val), relOf(e.key)})
	}
	lines = append(lines, mdTable([]string{"Imports", "File"}, foRows))
	return strings.Join(lines, "\n")
}

func sectionCouplingGraph(noGraph bool) string {
	lines := []string{mdSection(8, "Module Coupling Graph")}
	files := findNixFiles()
	fanOut, _ := parseImportsFromTree(files)
	root := filepath.Join(repoRoot(), "flake.nix")
	if !fileExists(root) {
		return lines[0] + "\n(flake.nix not found)"
	}
	lines = append(lines, mdSubsection("Import tree (from flake.nix)"))
	lines = append(lines, mdCode(buildImportTree(root, fanOut)))

	lines = append(lines, mdSubsection("Architectural layer validation"))
	lines = append(lines, "\nAllowed direction (foundational → specific):\n")
	lines = append(lines, "```\n"+strings.Join(layerOrder, "\n ↓\n")+"\n```\n")
	violations := checkLayerViolations(fanOut)
	if len(violations) > 0 {
		lines = append(lines, fmt.Sprintf("\n**%d violations detected:**\n", len(violations)))
		for _, v := range violations {
			lines = append(lines, fmt.Sprintf("- `%s` → `%s`", relOf(v[0]), relOf(v[1])))
		}
	} else {
		lines = append(lines, "\n**No layer violations.**\n")
	}

	if !noGraph {
		lines = append(lines, mdSubsection("Module Dependency Graph (Mermaid)"))
		lines = append(lines, buildMermaidGraph(fanOut))
	}
	return strings.Join(lines, "\n")
}

func sectionBuildDepth() string {
	lines := []string{mdSection(9, "Build Graph Depth")}
	files := findNixFiles()
	fanOut, _ := parseImportsFromTree(files)
	root := filepath.Join(repoRoot(), "flake.nix")
	if !fileExists(root) {
		return lines[0] + "\n(flake.nix not found)"
	}
	depth, path := deepestImportPath(root, fanOut)
	lines = append(lines, fmt.Sprintf("\nMaximum dependency depth from **flake.nix**: **%d**\n", depth))
	lines = append(lines, "Longest import chain:\n")
	tree := "flake.nix"
	for i, p := range path {
		indent := strings.Repeat("    ", i) + " └─ "
		tree += "\n" + indent + relOf(p)
	}
	lines = append(lines, "```\n"+tree+"\n```")
	return strings.Join(lines, "\n")
}
