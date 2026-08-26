package analyze

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)



func walkLOC(root, ext string, skip map[string]bool) int {
	total := 0
	_ = filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			if skip[filepath.Base(p)] {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(p) != ext {
			return nil
		}
		total += len(strings.Split(readNix(p), "\n"))
		return nil
	})
	return total
}

func discoverDomains() []string {
	var res []string
	dp := filepath.Join(repoRoot(), "domains")
	if !dirExists(dp) {
		return res
	}
	cats, _ := os.ReadDir(dp)
	for _, c := range cats {
		if !c.IsDir() {
			continue
		}
		doms, _ := os.ReadDir(filepath.Join(dp, c.Name()))
		for _, d := range doms {
			if d.IsDir() {
				res = append(res, filepath.Join(dp, c.Name(), d.Name()))
			}
		}
	}
	sort.Strings(res)
	return res
}

func domainName(d string) string {
	rel := relOf(d)
	parts := strings.Split(rel, string(filepath.Separator))
	if len(parts) >= 3 && parts[0] == "domains" {
		return parts[1] + "/" + parts[2]
	}
	return rel
}

func discoverThemes() []string {
	td := filepath.Join(repoRoot(), "themes")
	if !dirExists(td) {
		return nil
	}
	var res []string
	for _, f := range globNix(td) {
		name := strings.TrimSuffix(filepath.Base(f), ".nix")
		if name == "default" || name == "schema" {
			continue
		}
		res = append(res, name)
	}
	sort.Strings(res)
	return res
}

func globNix(dir string) []string {
	var out []string
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".nix") {
			out = append(out, filepath.Join(dir, e.Name()))
		}
	}
	return out
}



func nixDepthAndInterp(text string) (int, int) {
	depth := 0
	maxdepth := 0
	interp := 0
	inDouble := false
	inIndented := false
	inBlockComment := false
	lines := strings.Split(text, "\n")
	lineStartsInStr := make([]bool, len(lines))
	for i, line := range lines {
		lineStartsInStr[i] = inDouble || inIndented || inBlockComment
		j := 0
		for j < len(line) {
			if inBlockComment {
				if strings.HasPrefix(line[j:], "*/") {
					inBlockComment = false
					j += 2
				} else {
					j++
				}
				continue
			}
			if inIndented {
				if strings.HasPrefix(line[j:], "''") {
					rest := line[j+2:]
					if strings.HasPrefix(rest, "${") {
						j += 4
						continue
					}
					if strings.HasPrefix(rest, "'") {
						j += 3
						continue
					}
					if len(rest) > 0 && (rest[0] == '\n' || rest[0] == '\r') {
						j += 2
						continue
					}
					inIndented = false
					j += 2
					continue
				}
				if strings.HasPrefix(line[j:], "${") {
					interp++
					paren := 1
					j += 2
					for j < len(line) && paren > 0 {
						if line[j] == '{' {
							paren++
						} else if line[j] == '}' {
							paren--
						}
						j++
					}
					continue
				}
				j++
				continue
			}
			if inDouble {
				if line[j] == '\\' {
					j += 2
					continue
				}
				if line[j] == '"' {
					inDouble = false
					j++
					continue
				}
				if strings.HasPrefix(line[j:], "${") {
					interp++
					paren := 1
					j += 2
					for j < len(line) && paren > 0 {
						if line[j] == '{' {
							paren++
						} else if line[j] == '}' {
							paren--
						}
						j++
					}
					continue
				}
				j++
				continue
			}
			if strings.HasPrefix(line[j:], "//") {
				break
			}
			if strings.HasPrefix(line[j:], "/*") {
				inBlockComment = true
				j += 2
				continue
			}
			if strings.HasPrefix(line[j:], "${") {
				interp++
				paren := 1
				j += 2
				for j < len(line) && paren > 0 {
					if line[j] == '{' {
						paren++
					} else if line[j] == '}' {
						paren--
					}
					j++
				}
				continue
			}
			if strings.HasPrefix(line[j:], "''") {
				inIndented = true
				j += 2
				continue
			}
			if line[j] == '"' {
				inDouble = true
				j++
				continue
			}
			j++
		}
	}
	for i, line := range lines {
		if lineStartsInStr[i] {
			continue
		}
		s := strings.TrimSpace(line)
		if s == "let" || strings.HasPrefix(s, "let ") {
			depth++
			if depth > maxdepth {
				maxdepth = depth
			}
		} else if s == "in" || strings.HasPrefix(s, "in ") {
			if depth > 0 {
				depth--
			}
		}
	}
	return maxdepth, interp
}

func complexityScoreRaw(text string) (int, int, int, int, int) {
	score := 0
	maxdepth, interp := nixDepthAndInterp(text)
	if maxdepth >= 3 {
		score += 3
	} else if maxdepth >= 2 {
		score += 1
	}
	if interp > 30 {
		score += 3
	} else if interp > 15 {
		score += 2
	} else if interp > 5 {
		score += 1
	}
	cond := len(mkIfRe.FindAllString(text, -1))
	if cond > 10 {
		score += 3
	} else if cond > 5 {
		score += 2
	} else if cond > 2 {
		score += 1
	}
	loc := len(strings.Split(text, "\n"))
	if loc > 300 {
		score += 3
	} else if loc > 150 {
		score += 2
	} else if loc > 80 {
		score += 1
	}
	return score, maxdepth, interp, cond, loc
}

var (
	mkIfRe       = regexp.MustCompile(`mkIf|mkDefault|mkForce`)
	interpRe     = regexp.MustCompile(`\$\{`)
	domainRenderRe = regexp.MustCompile(`domains/([^/]+/[^/]+)/`)
)

func complexityLabel(text string) (string, int, string) {
	score := 0
	var reasons []string
	depth := 0
	maxdepth := 0
	for _, line := range strings.Split(text, "\n") {
		s := strings.TrimSpace(line)
		if s == "let" || strings.HasPrefix(s, "let ") {
			depth++
			if depth > maxdepth {
				maxdepth = depth
			}
		} else if s == "in" || strings.HasPrefix(s, "in ") {
			if depth > 0 {
				depth--
			}
		}
	}
	if maxdepth >= 3 {
		score += 3
		reasons = append(reasons, fmt.Sprintf("depth=%d", maxdepth))
	} else if maxdepth >= 2 {
		score += 1
		reasons = append(reasons, fmt.Sprintf("depth=%d", maxdepth))
	}
	interp := len(interpRe.FindAllString(text, -1))
	if interp > 30 {
		score += 3
		reasons = append(reasons, fmt.Sprintf("interp=%d", interp))
	} else if interp > 15 {
		score += 2
		reasons = append(reasons, fmt.Sprintf("interp=%d", interp))
	} else if interp > 5 {
		score += 1
		reasons = append(reasons, fmt.Sprintf("interp=%d", interp))
	}
	cond := len(mkIfRe.FindAllString(text, -1))
	if cond > 10 {
		score += 3
		reasons = append(reasons, fmt.Sprintf("cond=%d", cond))
	} else if cond > 5 {
		score += 2
		reasons = append(reasons, fmt.Sprintf("cond=%d", cond))
	} else if cond > 2 {
		score += 1
		reasons = append(reasons, fmt.Sprintf("cond=%d", cond))
	}
	loc := len(strings.Split(text, "\n"))
	if loc > 300 {
		score += 3
		reasons = append(reasons, fmt.Sprintf("LOC=%d", loc))
	} else if loc > 150 {
		score += 2
		reasons = append(reasons, fmt.Sprintf("LOC=%d", loc))
	} else if loc > 80 {
		score += 1
		reasons = append(reasons, fmt.Sprintf("LOC=%d", loc))
	}
	var label string
	switch {
	case score >= 7:
		label = "Very High"
	case score >= 5:
		label = "High"
	case score >= 3:
		label = "Medium"
	case score >= 1:
		label = "Low"
	default:
		label = "Minimal"
	}
	return label, score, strings.Join(reasons, ", ")
}



func sectionOverview(noEvalCost bool) string {
	lines := []string{mdSection(1, "Overview")}
	files := findNixFiles()
	totalNix := 0
	for _, f := range files {
		totalNix += len(strings.Split(readNix(f), "\n"))
	}
	skip := map[string]bool{".git": true, "result": true, "target": true}
	rustLOC := walkLOC(repoRoot(), ".rs", skip)
	shLOC := walkLOC(filepath.Join(repoRoot(), "runtime"), ".sh", skip)
	mdLOC := walkLOC(filepath.Join(repoRoot(), "openwiki"), ".md", skip)

	rows := [][]any{
		{"Files", fmt.Sprintf("%d .nix files, %d LOC", len(files), totalNix)},
		{"Rust", fmt.Sprintf("%d LOC", rustLOC)},
		{"Scripts", fmt.Sprintf("%d LOC (bash)", shLOC)},
		{"Docs", fmt.Sprintf("%d LOC (openwiki)", mdLOC)},
	}
	if !noEvalCost {
		rc, _, err := runExec([]string{"nix", "flake", "check", "--no-build"}, 60*time.Second)
		if rc == 0 {
			rows = append(rows, []any{"Flake check", "✓ passed"})
		} else {
			short := strings.TrimSpace(err)
			if short != "" {
				parts := strings.Split(short, "\n")
				short = parts[len(parts)-1]
			} else {
				short = "failed"
			}
			rows = append(rows, []any{"Flake check", "✗ " + short})
		}
	} else {
		rows = append(rows, []any{"Flake check", "skipped (--no-eval-cost)"})
	}
	lines = append(lines, mdTable([]string{"Metric", "Value"}, rows))
	return strings.Join(lines, "\n")
}

func sectionFileSizeHeatmap() string {
	lines := []string{mdSection(2, "File Size Heatmap (top 30)")}
	type entry struct {
		loc     int
		rel     string
		section string
	}
	var entries []entry
	for _, f := range findNixFiles() {
		loc := len(strings.Split(readNix(f), "\n"))
		rel := relOf(f)
		sec := rel
		if parts := strings.Split(rel, string(filepath.Separator)); len(parts) > 1 {
			sec = parts[0]
		}
		entries = append(entries, entry{loc, rel, sec})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].loc > entries[j].loc })
	rows := [][]any{}
	for _, e := range entries {
		if len(rows) >= 30 {
			break
		}
		rows = append(rows, []any{e.loc, e.rel, e.section})
	}
	lines = append(lines, mdTable([]string{"LOC", "File", "Section"}, rows))
	return strings.Join(lines, "\n")
}

func sectionDirectoryBreakdown() string {
	lines := []string{mdSection(3, "Directory Size Breakdown")}
	rows := [][]any{}
	for _, d := range []string{"lib", "domains", "toolchains", "themes", "hosts", "runtime"} {
		path := filepath.Join(repoRoot(), d)
		if !dirExists(path) {
			continue
		}
		count := 0
		loc := 0
		_ = filepath.Walk(path, func(p string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if info.IsDir() {
				if filepath.Base(p) == ".git" || filepath.Base(p) == "result" {
					return filepath.SkipDir
				}
				return nil
			}
			if filepath.Ext(p) != ".nix" {
				return nil
			}
			count++
			loc += len(strings.Split(readNix(p), "\n"))
			return nil
		})
		rows = append(rows, []any{d + "/", count, loc, ""})
	}
	lines = append(lines, mdTable([]string{"Directory", ".nix files", "LOC", "Extra"}, rows))
	return strings.Join(lines, "\n")
}

func sectionAttributeSurface() string {
	lines := []string{mdSection(4, "Attribute Surface")}
	pairs := [][]string{
		{"packages", "packages.x86_64-linux"},
		{"devShells", "devShells.x86_64-linux"},
		{"apps", "apps.x86_64-linux"},
		{"checks", "checks.x86_64-linux"},
		{"nixosConfig", "nixosConfigurations"},
		{"homeConfig", "homeConfigurations"},
	}
	rows := [][]any{}
	for _, p := range pairs {
		names := nixEvalAttrNames(p[1])
		label := strings.Join(names[:min(8, len(names))], ", ")
		if len(names) > 8 {
			label += "..."
		}
		rows = append(rows, []any{p[0], strconv.Itoa(len(names)), label})
	}
	lines = append(lines, mdTable([]string{"Output", "Count", "Entries"}, rows))
	return strings.Join(lines, "\n")
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func sectionConfigMatrix() string {
	lines := []string{mdSection(5, "Configuration Matrix")}
	hosts := discoverHostDirs()

	themes := discoverThemes()
	domains := discoverDomains()
	cats := map[string]bool{}
	for _, d := range domains {
		cat := strings.Split(relOf(d), string(filepath.Separator))[1]
		cats[cat] = true
	}
	architectures := nixEvalAttrNames("packages")
	if len(architectures) == 0 {
		architectures = []string{"x86_64-linux"}
	}
	rows := [][]any{
		{"Hosts", strconv.Itoa(len(hosts)), strings.Join(hosts, ", ")},
		{"Themes", strconv.Itoa(len(themes)), strings.Join(themes, ", ")},
		{"Architectures", strconv.Itoa(len(architectures)), strings.Join(architectures, ", ")},
		{"Domains", strconv.Itoa(len(domains)), fmt.Sprintf("%d domains in %d categories", len(domains), len(cats))},
	}
	lines = append(lines, mdTable([]string{"Dimension", "Count", "Values"}, rows))
	lines = append(lines, fmt.Sprintf("\n> **Possible host/theme configurations:** %d × %d = %d",
		len(hosts), len(themes), len(hosts)*len(themes)))
	return strings.Join(lines, "\n")
}

func sectionRenderCoverage() string {
	lines := []string{mdSection(6, "Domain Feature Coverage")}
	total := 0
	counts := map[string]int{}
	domainsPath := filepath.Join(repoRoot(), "domains")
	if !dirExists(domainsPath) {
		return lines[0] + "\n(no domains/)"
	}
	for _, cat := range sortedDirs(domainsPath) {
		catPath := filepath.Join(domainsPath, cat)
		for _, d := range sortedDirs(catPath) {
			dPath := filepath.Join(catPath, d)
			if !dirExists(dPath) {
				continue
			}
			total++
			if fileExists(filepath.Join(dPath, "render.nix")) {
				counts["render"]++
			}
			if fileExists(filepath.Join(dPath, "system.nix")) {
				counts["nixos"]++
			}
			if dirExists(filepath.Join(dPath, "checks")) {
				cnt := 0
				_ = filepath.Walk(filepath.Join(dPath, "checks"), func(p string, info os.FileInfo, err error) error {
					if err == nil && !info.IsDir() && strings.HasSuffix(p, ".nix") {
						cnt++
					}
					return nil
				})
				counts["checks"] += cnt
			}
		}
	}
	labels := map[string]string{
		"render":  "render.nix",
		"nixos":   "system.nix",
		"checks":   "domain checks",
	}
	rows := [][]any{}
	for _, k := range []string{"render", "nixos", "checks"} {
		n := counts[k]
		pct := "—"
		if total > 0 {
			pct = fmt.Sprintf("%d%%", n*100/total)
		}
		rows = append(rows, []any{labels[k], strconv.Itoa(n), pct})
	}
	rows = append(rows, []any{"**total domains**", strconv.Itoa(total), "100%"})
	lines = append(lines, mdTable([]string{"Feature", "Count", "Coverage"}, rows))
	return strings.Join(lines, "\n")
}

func sortedDirs(dir string) []string {
	var out []string
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if e.IsDir() {
			out = append(out, e.Name())
		}
	}
	sort.Strings(out)
	return out
}
