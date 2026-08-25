package analyze

import (
	"fmt"
	"sort"
	"strings"
	"time"
)

func sectionHotspotTable() string {
	lines := []string{mdSection(27, "Hotspot Table")}
	lines = append(lines, "> Cross-references file size, git churn, dependency counts, and complexity into a single view.\n")
	lines = append(lines, "> **Columns**: LOC (size), Churn (commits/year), Imports (fan-out), Dependents (fan-in), Complexity (derived from nesting depth, string interpolation, conditional count).\n")

	files := findNixFiles()
	fanOut, fanIn := parseImportsFromTree(files)
	churn := gitChurn()

	rows := [][]any{}
	for _, f := range files {
		rel := relOf(f)
		loc := len(strings.Split(readNix(f), "\n"))
		ch := churn[rel]
		im := len(fanOut[f])
		de := fanIn[f]
		label, score, _ := complexityLabel(readNix(f))
		rows = append(rows, []any{fmt.Sprintf("`%s`", rel), loc, ch, im, de, label, score})
	}
	sort.Slice(rows, func(i, j int) bool {
		if toInt(rows[i][1]) != toInt(rows[j][1]) {
			return toInt(rows[i][1]) > toInt(rows[j][1])
		}
		return toInt(rows[i][2]) > toInt(rows[j][2])
	})
	if len(rows) > 25 {
		rows = rows[:25]
	}
	lines = append(lines, mdTable([]string{"File", "LOC", "Churn", "Imports", "Dependents", "Complexity", "Score"}, rows))
	return strings.Join(lines, "\n")
}

func sectionStabilityIndex() string {
	lines := []string{mdSection(28, "Stability Index")}
	lines = append(lines, "> Cross-references git churn with file recency. **Hot** = high churn + recently modified, **Active** = moderate churn, **Stable** = low churn, **Archived** = no changes in 6+ months.\n")

	churn, fileLastDate := gitStability()
	now := time.Now()
	rows := [][]any{}
	for _, f := range findNixFiles() {
		rel := relOf(f)
		ch := churn[rel]
		lastStr := fileLastDate[rel]
		var last time.Time
		var err error
		if lastStr != "" && len(lastStr) >= 10 {
			last, err = time.Parse("2006-01-02", lastStr[:10])
		}
		daysAgo := 999
		if err == nil && !last.IsZero() {
			daysAgo = int(now.Sub(last).Hours() / 24)
		}
		var label string
		switch {
		case ch >= 10 && daysAgo < 60:
			label = "Hot"
		case ch >= 5 && daysAgo < 180:
			label = "Active"
		case ch >= 1:
			label = "Stable"
		default:
			label = "Archived"
		}
		if lastStr != "" {
			dateShort := lastStr
			if len(dateShort) >= 10 {
				dateShort = dateShort[:10]
			}
			rows = append(rows, []any{fmt.Sprintf("`%s`", rel), ch, dateShort, label})
		} else if ch > 0 {
			rows = append(rows, []any{fmt.Sprintf("`%s`", rel), ch, "(no date)", label})
		}
	}
	sort.Slice(rows, func(i, j int) bool {
		if toInt(rows[i][1]) != toInt(rows[j][1]) {
			return toInt(rows[i][1]) > toInt(rows[j][1])
		}
		return fmt.Sprintf("%v", rows[i][2]) < fmt.Sprintf("%v", rows[j][2])
	})
	if len(rows) > 20 {
		rows = rows[:20]
	}
	lines = append(lines, mdTable([]string{"File", "Churn", "Last changed", "Label"}, rows))
	return strings.Join(lines, "\n")
}
