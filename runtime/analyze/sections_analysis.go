package analyze

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

var (
	recRe  = regexp.MustCompile(`\brec\b`)
	withRe = regexp.MustCompile(`\bwith\b`)
)

func sectionOptionInventory() string {
	lines := []string{mdSection(17, "Option Inventory")}
	mkopt := rgCount("mkOption", true)
	mkenable := rgCount("mkEnableOption", true)
	mkif := rgCount("mkIf", true)
	rows := [][]any{
		{"mkOption", mkopt},
		{"mkEnableOption", mkenable},
		{"mkIf", mkif},
	}
	lines = append(lines, mdTable([]string{"Construct", "Count"}, rows))

	lines = append(lines, mdSubsection("Option namespace references"))
	matches := rgOnly(`options\.\w+`)
	namespaces := map[string]int{}
	nsRe := regexp.MustCompile(`options\.(\w+)`)
	for _, m := range matches {
		sm := nsRe.FindStringSubmatch(m)
		if sm != nil {
			namespaces[sm[1]]++
		}
	}
	keys := make([]string, 0, len(namespaces))
	for k := range namespaces {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	nsRows := [][]any{}
	for _, k := range keys {
		nsRows = append(nsRows, []any{k, namespaces[k]})
	}
	if len(nsRows) > 0 {
		lines = append(lines, mdTable([]string{"Namespace", "References"}, nsRows))
	}
	return strings.Join(lines, "\n")
}

func sectionNixIdiom() string {
	lines := []string{mdSection(18, "Nix Idiom Usage")}
	idioms := []string{
		"lib.genAttrs", "lib.optional", "lib.optionalAttrs", "lib.mapAttrs",
		"lib.mkMerge", "lib.pipe", "lib.foldl'", "lib.filterAttrs",
		"lib.nameValuePair", "lib.listToAttrs", "lib.concatMap",
		"lib.flatten", "lib.zipAttrsWith",
	}
	matches := rgOnly(`lib\.\w+`)
	counts := map[string]int{}
	for _, m := range matches {
		counts[m]++
	}
	rows := [][]any{}
	for _, idiom := range idioms {
		rows = append(rows, []any{idiom, counts[idiom]})
	}
	allOthers := map[string]int{}
	for k, v := range counts {
		found := false
		for _, idiom := range idioms {
			if idiom == k {
				found = true
				break
			}
		}
		if !found {
			allOthers[k] = v
		}
	}
	type kv2 struct {
		k string
		v int
	}
	var others []kv2
	for k, v := range allOthers {
		others = append(others, kv2{k, v})
	}
	sort.Slice(others, func(i, j int) bool { return others[i].v > others[j].v })
	for i := 0; i < min(5, len(others)); i++ {
		rows = append(rows, []any{others[i].k, others[i].v})
	}
	sort.Slice(rows, func(i, j int) bool {
		return toInt(rows[i][1]) > toInt(rows[j][1])
	})
	lines = append(lines, mdTable([]string{"Idiom", "Count"}, rows))
	return strings.Join(lines, "\n")
}

func toInt(v any) int {
	switch x := v.(type) {
	case int:
		return x
	default:
		return 0
	}
}

func sectionConditionalBuiltins() string {
	lines := []string{mdSection(19, "Conditional & Builtins Usage")}
	lines = append(lines, mdSubsection("Conditional logic"))
	condPats := []string{"mkIf", "mkDefault", "mkForce", "mkOption", "mkEnableOption"}
	rows := [][]any{}
	for _, pat := range condPats {
		total := rgCount(pat, true)
		files := len(rgList(pat, true))
		rows = append(rows, []any{pat, total, files})
	}
	lines = append(lines, mdTable([]string{"Construct", "Count", "Files"}, rows))

	lines = append(lines, mdSubsection("Builtins frequency (top 15)"))
	matches := rgOnly(`builtins\.\w+`)
	counts := map[string]int{}
	for _, m := range matches {
		counts[m]++
	}
	type kv2 struct {
		k string
		v int
	}
	var top []kv2
	for k, v := range counts {
		top = append(top, kv2{k, v})
	}
	sort.Slice(top, func(i, j int) bool { return top[i].v > top[j].v })
	if len(top) > 15 {
		top = top[:15]
	}
	br := [][]any{}
	for _, t := range top {
		br = append(br, []any{t.k, t.v})
	}
	if len(br) > 0 {
		lines = append(lines, mdTable([]string{"Builtin", "Count"}, br))
	}
	return strings.Join(lines, "\n")
}

func sectionComplexityMetrics() string {
	lines := []string{mdSection(20, "Complexity Metrics")}
	rows := [][]any{}
	for _, f := range findNixFiles() {
		score, maxdepth, interp, cond, loc := complexityScoreRaw(readNix(f))
		if score == 0 {
			continue
		}
		var reasons []string
		if maxdepth >= 2 {
			reasons = append(reasons, fmt.Sprintf("depth=%d", maxdepth))
		}
		if interp > 5 {
			reasons = append(reasons, fmt.Sprintf("interp=%d", interp))
		}
		if cond > 2 {
			reasons = append(reasons, fmt.Sprintf("cond=%d", cond))
		}
		if loc > 80 {
			reasons = append(reasons, fmt.Sprintf("LOC=%d", loc))
		}
		rows = append(rows, []any{score, fmt.Sprintf("`%s`", relOf(f)), strings.Join(reasons, ", ")})
	}
	sort.Slice(rows, func(i, j int) bool {
		return toInt(rows[i][0]) > toInt(rows[j][0])
	})
	lines = append(lines, mdSubsection("All files with non-trivial complexity"))
	lines = append(lines, mdTable([]string{"Score", "File", "Contributing factors"}, rows))
	return strings.Join(lines, "\n")
}

func sectionInterestingComplexity() string {
	lines := []string{mdSection(21, `"Interesting" Complexity Metrics`)}

	metrics := []string{
		"Deepest attrset nesting", "Most rec blocks", "Most with blocks",
		"Deepest mkIf nesting", "Largest attrset", "Largest list",
		"Longest string (lines)", "Deepest function pipeline (|>)",
	}
	topByMetric := map[string][]kv{}
	for _, f := range findNixFiles() {
		text := readNix(f)
		rel := relOf(f)

		maxBrace := 0
		braceDepth := 0
		for _, ch := range text {
			if ch == '{' {
				braceDepth++
				if braceDepth > maxBrace {
					maxBrace = braceDepth
				}
			} else if ch == '}' {
				if braceDepth > 0 {
					braceDepth--
				}
			}
		}
		topByMetric["Deepest attrset nesting"] = append(topByMetric["Deepest attrset nesting"], kv{rel, maxBrace})

		recCount := len(recRe.FindAllString(text, -1))
		topByMetric["Most rec blocks"] = append(topByMetric["Most rec blocks"], kv{rel, recCount})

		withCount := len(withRe.FindAllString(text, -1))
		topByMetric["Most with blocks"] = append(topByMetric["Most with blocks"], kv{rel, withCount})

		maxMkif := 0
		mkIfRe2 := regexp.MustCompile(`\bmkIf\b`)
		for _, m := range mkIfRe2.FindAllStringIndex(text, -1) {
			pos := m[0]
			end := pos + 500
			if end > len(text) {
				end = len(text)
			}
			window := text[pos:end]
			cnt := len(mkIfRe2.FindAllString(window, -1))
			if cnt > maxMkif {
				maxMkif = cnt
			}
		}
		topByMetric["Deepest mkIf nesting"] = append(topByMetric["Deepest mkIf nesting"], kv{rel, maxMkif})

		attrCount := estimateAttrsetSize(text)
		topByMetric["Largest attrset"] = append(topByMetric["Largest attrset"], kv{rel, attrCount})

		listEntries := estimateListEntries(text)
		topByMetric["Largest list"] = append(topByMetric["Largest list"], kv{rel, listEntries})

		strLines := longestString(text)
		topByMetric["Longest string (lines)"] = append(topByMetric["Longest string (lines)"], kv{rel, strLines})

		pipeDepth := 0
		for _, line := range strings.Split(text, "\n") {
			if c := strings.Count(line, "|>"); c > pipeDepth {
				pipeDepth = c
			}
		}
		topByMetric["Deepest function pipeline (|>)"] = append(topByMetric["Deepest function pipeline (|>)"], kv{rel, pipeDepth})
	}

	for _, metric := range metrics {
		lines = append(lines, mdSubsection(titleCase(metric)))
		entries := topByMetric[metric]
		sort.Slice(entries, func(i, j int) bool { return entries[i].val > entries[j].val })
		rows := [][]any{}
		for _, e := range entries {
			if e.val <= 0 {
				break
			}
			if len(rows) >= 8 {
				break
			}
			rows = append(rows, []any{e.val, fmt.Sprintf("`%s`", e.key)})
		}
		lines = append(lines, mdTable([]string{"Value", "File"}, rows))
	}
	return strings.Join(lines, "\n")
}

func estimateAttrsetSize(text string) int {
	count := 0
	inBrace := 0
	for _, line := range strings.Split(text, "\n") {
		stripped := strings.TrimSpace(line)
		inBrace += strings.Count(stripped, "{")
		inBrace -= strings.Count(stripped, "}")
		if inBrace > 0 && strings.Contains(stripped, "=") && strings.HasSuffix(stripped, ";") {
			count++
		}
	}
	return count
}

func estimateListEntries(text string) int {
	maxEntries := 0
	curEntries := 0
	depth := 0
	for _, line := range strings.Split(text, "\n") {
		stripped := strings.TrimSpace(line)
		if stripped == "" || strings.HasPrefix(stripped, "#") {
			continue
		}
		open := strings.Count(line, "[")
		close := strings.Count(line, "]")
		if depth > 0 {
			if close == 0 {
				curEntries++
			} else {
				if idx := strings.Index(stripped, "]"); idx > 0 {
					before := strings.TrimSpace(stripped[:idx])
					if before != "" && before != "[" {
						curEntries++
					}
				}
				if depth+open-close <= 0 {
					if curEntries > maxEntries {
						maxEntries = curEntries
					}
					curEntries = 0
				}
			}
		} else if open > 0 && close == 0 {
			curEntries = 0
		} else if open > 0 && close > 0 && open == close {
			inside := strings.TrimSpace(line[strings.Index(line, "[")+1 : strings.LastIndex(line, "]")])
			if inside != "" {
				parts := strings.Fields(inside)
				if len(parts) > maxEntries {
					maxEntries = len(parts)
				}
			}
		}
		depth += open - close
		if depth < 0 {
			depth = 0
			curEntries = 0
		}
	}
	if curEntries > maxEntries {
		maxEntries = curEntries
	}
	return maxEntries
}

func longestString(text string) int {
	maxLines := 0
	inString := false
	current := 0
	i := 0
	for i < len(text) {
		if !inString && strings.HasPrefix(text[i:], "''") {
			inString = true
			current = 1
			i += 2
		} else if inString && strings.HasPrefix(text[i:], "''") {
			inString = false
			if current > maxLines {
				maxLines = current
			}
			i += 2
		} else if inString {
			if text[i] == '\n' {
				current++
			}
			i++
		} else {
			i++
		}
	}
	return maxLines
}

func sectionErrorHandling() string {
	lines := []string{mdSection(22, "Error Handling")}
	pats := [][]string{
		{`builtins\.throw|throw `, "throw"},
		{`builtins\.abort|abort `, "abort"},
		{`\bassert `, "assert"},
	}
	counts := map[string]int{}
	for _, p := range pats {
		counts[p[1]] = rgCount(p[0], false)
	}
	rows := [][]any{}
	for _, p := range pats {
		rows = append(rows, []any{p[1], counts[p[1]]})
	}
	lines = append(lines, mdTable([]string{"Construct", "Count"}, rows))

	lines = append(lines, mdSubsection("Throw locations"))
	for _, l := range rgList(`throw "`, false) {
		lines = append(lines, fmt.Sprintf("- `%s`", l))
		if len(lines) > 14 {
			break
		}
	}
	return strings.Join(lines, "\n")
}

func titleCase(s string) string {
	words := strings.Split(s, " ")
	for i, w := range words {
		if w == "" {
			continue
		}
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}
