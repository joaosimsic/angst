package analyze

import (
	"fmt"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

var domainRenderPathRe = regexp.MustCompile(`domains/([^/]+/[^/]+)/`)

func sectionThemeDomainCoverage(noEvalCost bool) string {
	lines := []string{mdSection(29, "Theme \u00d7 Domain Coverage")}
	lines = append(lines, "> \u2713 = render produces output, \u2717 = render throws, \u2014 = no render.nix\n")
	if noEvalCost {
		lines = append(lines, "> Skipped (`--no-eval-cost`)\n")
		return strings.Join(lines, "\n")
	}
	themes := discoverThemes()
	if len(themes) == 0 {
		lines = append(lines, "(no themes)")
		return strings.Join(lines, "\n")
	}
	allDomains := discoverDomains()
	domainNames := []string{}
	for _, d := range allDomains {
		domainNames = append(domainNames, domainName(d))
	}
	renderDomainNames := map[string]bool{}
	for _, d := range allDomains {
		if fileExists(filepath.Join(d, "render.nix")) {
			renderDomainNames[domainName(d)] = true
		}
	}
	if len(renderDomainNames) == 0 {
		lines = append(lines, "(no domains with render.nix)")
		return strings.Join(lines, "\n")
	}
	matrix := map[string]map[string]string{}
	for _, theme := range themes {
		matrix[theme] = map[string]string{}
		for _, dn := range domainNames {
			if renderDomainNames[dn] {
				matrix[theme][dn] = "?"
			} else {
				matrix[theme][dn] = "\u2014"
			}
		}
		rc, out, errStr := runExec([]string{
			"nix", "eval", "--apply", fmt.Sprintf(`f: f "generic" "%s"`, theme),
			"--raw", ".#lib.renderDomainOutputPathsFor", "--no-warn-dirty",
		}, 30*time.Second)
		if rc == 0 && strings.TrimSpace(out) != "" {
			covered := map[string]bool{}
			for _, p := range strings.Split(strings.TrimSpace(out), "\n") {
				if m := domainRenderPathRe.FindStringSubmatch(strings.TrimSpace(p)); m != nil {
					covered[m[1]] = true
				}
			}
			for dn := range renderDomainNames {
				if covered[dn] {
					matrix[theme][dn] = "\u2713"
				} else {
					matrix[theme][dn] = "\u2717"
				}
			}
		} else {
			failing := ""
			if m := domainRenderPathRe.FindStringSubmatch(errStr); m != nil {
				failing = m[1]
			}
			for dn := range renderDomainNames {
				if failing != "" && dn == failing {
					matrix[theme][dn] = "\u2717"
				} else {
					matrix[theme][dn] = ""
				}
			}
		}
	}
	headers := append([]string{"Theme"}, domainNames...)
	rows := [][]any{}
	themesSorted := make([]string, 0, len(matrix))
	for k := range matrix {
		themesSorted = append(themesSorted, k)
	}
	sort.Strings(themesSorted)
	for _, theme := range themesSorted {
		row := []any{fmt.Sprintf("`%s`", theme)}
		for _, dn := range domainNames {
			row = append(row, matrix[theme][dn])
		}
		rows = append(rows, row)
	}
	lines = append(lines, mdTable(headers, rows))
	return strings.Join(lines, "\n")
}

func sectionDomainFeatures() string {
	lines := []string{mdSection(30, "Domain Features")}
	lines = append(lines, "> Which optional features each domain provides.\n")
	allDomains := discoverDomains()
	if len(allDomains) == 0 {
		lines = append(lines, "(no domains)")
		return strings.Join(lines, "\n")
	}
	rows := [][]any{}
	for _, d := range allDomains {
		dn := domainName(d)
		rows = append(rows, []any{
			dn,
			checkMark(fileExists(filepath.Join(d, "render.nix"))),
			checkMark(fileExists(filepath.Join(d, "nixos.nix"))),
			checkMark(dirExists(filepath.Join(d, "config"))),
			checkMark(fileExists(filepath.Join(d, "module.nix"))),
		})
	}
	sort.Slice(rows, func(i, j int) bool { return fmt.Sprintf("%v", rows[i][0]) < fmt.Sprintf("%v", rows[j][0]) })
	lines = append(lines, mdTable([]string{"Domain", "render", "nixos", "config/", "module"}, rows))
	return strings.Join(lines, "\n")
}

func checkMark(ok bool) string {
	if ok {
		return "\u2713"
	}
	return "\u2014"
}

func sectionCheckResults(noEvalCost bool) string {
	lines := []string{mdSection(31, "Check Results Breakdown")}
	if noEvalCost {
		lines = append(lines, "> Skipped (`--no-eval-cost`)\n")
		return strings.Join(lines, "\n")
	}
	checkNames := nixEvalAttrNames("checks.x86_64-linux")
	if len(checkNames) == 0 {
		lines = append(lines, "_(no checks found)_")
		return strings.Join(lines, "\n")
	}
	sort.Strings(checkNames)
	passCount, failCount := 0, 0
	rows := [][]any{}
	for _, name := range checkNames {
		start := time.Now()
		rc, out, errStr := runExec([]string{"nix", "build", "--no-link", ".#checks.x86_64-linux." + name, "--no-warn-dirty"}, 90*time.Second)
		elapsed := time.Since(start).Seconds()
		status := "\u2713"
		detail := ""
		if rc != 0 {
			status = "\u2717"
			failCount++
			combined := strings.TrimSpace(out + "\n" + errStr)
			if combined != "" {
				short := combined
				if len(short) > 300 {
					short = short[:300]
				}
				detail = strings.ReplaceAll(short, "\n", " ")
			}
		} else {
			passCount++
		}
		rows = append(rows, []any{fmt.Sprintf("`%s`", name), status, fmt.Sprintf("%.2fs", elapsed), detail})
	}
	lines = append(lines, mdTable([]string{"Check", "Result", "Time", "Details"}, rows))
	lines = append(lines, fmt.Sprintf("\n**%d passed, %d failed**\n", passCount, failCount))

	rc, out, _ := runExec([]string{"nix", "eval", ".#lib.themeLint", "--raw", "--no-warn-dirty"}, 30*time.Second)
	if rc == 0 && strings.TrimSpace(out) != "" {
		lines = append(lines, mdSubsection("Theme lint detail"))
		lines = append(lines, mdCode(strings.TrimSpace(out)))
	} else {
		lines = append(lines, mdSubsection("Theme lint detail"))
		lines = append(lines, "_(could not evaluate themeLint)_\n")
	}
	return strings.Join(lines, "\n")
}

func countRenderOutputLines(renderPath string) (int, int) {
	text := readNix(renderPath)
	fileCount := 0
	totalLines := 0
	inBlock := false
	blockLines := 0
	for _, line := range strings.Split(text, "\n") {
		stripped := strings.TrimSpace(line)
		if !inBlock {
			if matched, _ := regexp.MatchString(`=\s*''\s*$`, stripped); matched {
				inBlock = true
				blockLines = 0
				continue
			}
		}
		if inBlock {
			if matched, _ := regexp.MatchString(`''\s*[;\]})@]?\s*$`, stripped); matched {
				inBlock = false
				totalLines += blockLines
				continue
			}
			blockLines++
		}
	}
	fileCount = len(regexp.MustCompile(`path\s*=\s*"[^"]+"`).FindAllString(text, -1))
	return fileCount, totalLines
}

func sectionRenderOutputSizes() string {
	lines := []string{mdSection(32, "Rendered Output Sizes")}
	lines = append(lines, "> Estimated output lines from multi-line string literals in render.nix.\n")
	allDomains := discoverDomains()
	var renderDomains [][]string
	for _, d := range allDomains {
		if fileExists(filepath.Join(d, "render.nix")) {
			renderDomains = append(renderDomains, []string{d, domainName(d)})
		}
	}
	if len(renderDomains) == 0 {
		lines = append(lines, "(no domains with render.nix)")
		return strings.Join(lines, "\n")
	}
	rows := [][]any{}
	for _, pair := range renderDomains {
		d, dn := pair[0], pair[1]
		fc, tl := countRenderOutputLines(filepath.Join(d, "render.nix"))
		rows = append(rows, []any{dn, fc, tl})
	}
	sort.Slice(rows, func(i, j int) bool { return toInt(rows[i][2]) > toInt(rows[j][2]) })
	lines = append(lines, mdTable([]string{"Domain", "Output files", "Est. output lines"}, rows))
	return strings.Join(lines, "\n")
}

func sectionGrowthVelocity() string {
	lines := []string{mdSection(33, "Growth Velocity")}
	lines = append(lines, "> Monthly lines added/removed across .nix, .sh, and .rs files (excludes merges).\n")
	if !hasCmd("git") {
		lines = append(lines, "> `git` not found.\n")
		return strings.Join(lines, "\n")
	}
	rc, out, _ := runExec([]string{
		"git", "log", "--since=12 months ago", "--format=COMMIT %ai", "--numstat", "--no-merges", "--", "*.nix", "*.sh", "*.rs",
	}, 60*time.Second)
	if rc != 0 || strings.TrimSpace(out) == "" {
		lines = append(lines, "> No commit history found.\n")
		return strings.Join(lines, "\n")
	}
	type monthStat struct {
		added, removed, commits int
	}
	monthly := map[string]*monthStat{}
	var currentMonth *string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "COMMIT ") {
			parts := strings.SplitN(line, " ", 2)
			if len(parts) == 2 {
				m := parts[1][:7]
				if _, ok := monthly[m]; !ok {
					monthly[m] = &monthStat{}
				}
				monthly[m].commits++
				currentMonth = &m
			}
			continue
		}
		if currentMonth != nil && strings.Contains(line, "\t") {
			parts := strings.Split(line, "\t")
			if len(parts) >= 2 {
				added := 0
				removed := 0
				if parts[0] != "-" {
					added, _ = strconv.Atoi(parts[0])
				}
				if parts[1] != "-" {
					removed, _ = strconv.Atoi(parts[1])
				}
				monthly[*currentMonth].added += added
				monthly[*currentMonth].removed += removed
			}
		}
	}
	if len(monthly) == 0 {
		lines = append(lines, "> No commit history found.\n")
		return strings.Join(lines, "\n")
	}
	months := make([]string, 0, len(monthly))
	for k := range monthly {
		months = append(months, k)
	}
	sort.Strings(months)
	rows := [][]any{}
	totalAdded, totalRemoved := 0, 0
	for _, m := range months {
		st := monthly[m]
		net := st.added - st.removed
		netStr := strconv.Itoa(net)
		if net >= 0 {
			netStr = "+" + netStr
		}
		rows = append(rows, []any{m, st.added, st.removed, netStr, st.commits})
		totalAdded += st.added
		totalRemoved += st.removed
	}
	lines = append(lines, mdTable([]string{"Month", "Added", "Removed", "Net", "Commits"}, rows))
	lines = append(lines, fmt.Sprintf("\n> **12-month totals:** +%d added, \u2212%d removed, net %+d", totalAdded, totalRemoved, totalAdded-totalRemoved))
	return strings.Join(lines, "\n")
}

var tokenDefs = [][2]string{
	{"palette.bg.base", `p\.background\.base\b|t\.safe\.foregroundOnBackground\b`},
	{"palette.bg.variant", `p\.background\.variant\b`},
	{"palette.sf.base", `p\.surface\.base\b|t\.safe\.foregroundOnSurfaceBase\b`},
	{"palette.sf.variant", `p\.surface\.variant\b|t\.safe\.foregroundOnSurfaceVariant\b`},
	{"palette.fg.base", `p\.foreground\.base\b`},
	{"palette.fg.variant", `p\.foreground\.variant\b|t\.safe\.\w*OnForegroundVariant\b`},
	{"palette.ac.base", `p\.accent\.base\b`},
	{"palette.ac.variant", `p\.accent\.variant\b|t\.safe\.foregroundOnAccentVariant\b`},
	{"palette.dim", `p\.dim\b`},
	{"ansi.error", `\bt\.ansi\.error\b|\ba\.error\b`},
	{"ansi.warn", `\bt\.ansi\.warn\b|\ba\.warn\b`},
	{"ansi.info", `\bt\.ansi\.info\b|\ba\.info\b`},
	{"ansi.success", `\bt\.ansi\.success\b|\ba\.success\b`},
}

func tokenCounts(renderPath string) map[string]int {
	text := readNix(renderPath)
	res := map[string]int{}
	for _, td := range tokenDefs {
		re := regexp.MustCompile(td[1])
		res[td[0]] = len(re.FindAllString(text, -1))
	}
	return res
}

func sectionTokenUsage() string {
	lines := []string{mdSection(34, "Theme Token Usage Audit")}
	lines = append(lines, "> How many times each schema token is referenced in each render.nix.\n")
	lines = append(lines, "> Token lookup uses regex patterns covering `${p.xxx}`, `${t.safe.xxx}`, `${a.xxx}`, and `${t.ansi.xxx}` references.\n")
	allDomains := discoverDomains()
	var renderDomains [][]string
	for _, d := range allDomains {
		if fileExists(filepath.Join(d, "render.nix")) {
			renderDomains = append(renderDomains, []string{d, domainName(d)})
		}
	}
	if len(renderDomains) == 0 {
		lines = append(lines, "(no domains with render.nix)")
		return strings.Join(lines, "\n")
	}
	tokenNames := make([]string, len(tokenDefs))
	for i, td := range tokenDefs {
		tokenNames[i] = td[0]
	}
	shortNames := make([]string, len(tokenNames))
	for i, tn := range tokenNames {
		shortNames[i] = strings.ReplaceAll(strings.ReplaceAll(tn, "palette.", ""), ".", "\u00b7")
	}
	rows := [][]any{}
	tokenTotals := map[string]int{}
	tokenDomainCounts := map[string]int{}
	for _, td := range tokenDefs {
		tokenTotals[td[0]] = 0
		tokenDomainCounts[td[0]] = 0
	}
	for _, pair := range renderDomains {
		d, dn := pair[0], pair[1]
		counts := tokenCounts(filepath.Join(d, "render.nix"))
		row := []any{dn}
		for _, tn := range tokenNames {
			c := counts[tn]
			if c > 0 {
				row = append(row, c)
			} else {
				row = append(row, "\u2014")
			}
			tokenTotals[tn] += c
			if c > 0 {
				tokenDomainCounts[tn]++
			}
		}
		rows = append(rows, row)
	}
	headers := append([]string{"Domain"}, shortNames...)
	lines = append(lines, mdSubsection("Per-domain usage"))
	lines = append(lines, mdTable(headers, rows))

	lines = append(lines, mdSubsection("Token popularity summary"))
	summaryRows := [][]any{}
	for _, tn := range tokenNames {
		summaryRows = append(summaryRows, []any{fmt.Sprintf("`%s`", tn), tokenTotals[tn], tokenDomainCounts[tn]})
	}
	sort.Slice(summaryRows, func(i, j int) bool {
		if toInt(summaryRows[i][1]) != toInt(summaryRows[j][1]) {
			return toInt(summaryRows[i][1]) > toInt(summaryRows[j][1])
		}
		return fmt.Sprintf("%v", summaryRows[i][0]) < fmt.Sprintf("%v", summaryRows[j][0])
	})
	lines = append(lines, mdTable([]string{"Token", "Total uses", "Used by (domains)"}, summaryRows))
	return strings.Join(lines, "\n")
}
