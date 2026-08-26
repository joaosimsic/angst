package analyze

import (
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"
)

func slug(s string) string {
	s = strings.ToLower(s)
	re := regexp.MustCompile(`[^a-z0-9]+`)
	s = re.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}

func Run(args []string) int {
	noEvalCost := false
	noGraph := false
	memEnabled := false
	memHosts := ""
	memFormat := ""
	memJSONPath := ""
	var outFile string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--no-eval-cost":
			noEvalCost = true
		case "--no-graph":
			noGraph = true
		case "--mem":
			memEnabled = true
		case "--mem-hosts":
			if i+1 < len(args) {
				memHosts = args[i+1]
				memEnabled = true
				i++
			}
		case "--mem-format":
			if i+1 < len(args) {
				memFormat = args[i+1]
				i++
			}
		case "--mem-json":
			if i+1 < len(args) {
				memJSONPath = args[i+1]
				memEnabled = true
				i++
			}
		case "-o", "--output":
			if i+1 < len(args) {
				outFile = args[i+1]
				i++
			}
		case "-h", "--help":
			fmt.Print("Usage: analyze [--no-eval-cost] [--no-graph] [--mem [--mem-hosts h1,h2|all] [--mem-format md|json] [--mem-json FILE]] [-o FILE]\n")
			return 0
		}
	}
	if memFormat == "json" && memJSONPath == "" {
		memJSONPath = "analysis-memory.json"
	}

	type sec struct {
		heading string
		content string
	}
	_ = memFormat
	defs := []struct {
		heading string
		fn      func() string
	}{
		{"1. Overview", func() string { return sectionOverview(noEvalCost) }},
		{"2. File Size Heatmap (top 30)", func() string { return sectionFileSizeHeatmap() }},
		{"3. Directory Size Breakdown", func() string { return sectionDirectoryBreakdown() }},
		{"4. Attribute Surface", func() string { return sectionAttributeSurface() }},
		{"5. Configuration Matrix", func() string { return sectionConfigMatrix() }},
		{"6. Domain Feature Coverage", func() string { return sectionRenderCoverage() }},
		{"7. Dependency Fan-in / Fan-out", func() string { return sectionDependencyFan() }},
		{"8. Module Coupling Graph", func() string { return sectionCouplingGraph(noGraph) }},
		{"9. Build Graph Depth", func() string { return sectionBuildDepth() }},
		{"10. Duplication Hotspots", func() string { return sectionDuplication() }},
		{"11. Hardcoded Strings Inventory", func() string { return sectionHardcodedStrings() }},
		{"12. Domain Inventory", func() string { return sectionDomainInventory() }},
		{"13. Theme Inventory", func() string { return sectionThemeInventory() }},
		{"14. System Feature Inventory", func() string { return sectionCapabilitiesInventory() }},
		{"15. Toolchain Inventory", func() string { return sectionToolchainInventory() }},
		{"16. Host Inventory", func() string { return sectionHostInventory() }},
		{"17. Option Inventory", func() string { return sectionOptionInventory() }},
		{"18. Nix Idiom Usage", func() string { return sectionNixIdiom() }},
		{"19. Conditional & Builtins Usage", func() string { return sectionConditionalBuiltins() }},
		{"20. Complexity Metrics", func() string { return sectionComplexityMetrics() }},
		{"21. \"Interesting\" Complexity Metrics", func() string { return sectionInterestingComplexity() }},
		{"22. Error Handling", func() string { return sectionErrorHandling() }},
		{"23. Dead Code", func() string { return sectionDeadCode() }},
		{"24. Anti-Patterns (statix)", func() string { return sectionAntiPatterns() }},
		{"25. Evaluation Cost", func() string { return sectionEvalCost(noEvalCost) }},
		{"26. Technical Debt Score", func() string { return sectionTechDebt() }},
		{"27. Hotspot Table", func() string { return sectionHotspotTable() }},
		{"28. Stability Index", func() string { return sectionStabilityIndex() }},
		{"29. Theme \u00d7 Domain Coverage", func() string { return sectionThemeDomainCoverage(noEvalCost) }},
		{"30. Domain Features", func() string { return sectionDomainFeatures() }},
		{"31. Check Results Breakdown", func() string { return sectionCheckResults(noEvalCost) }},
		{"32. Rendered Output Sizes", func() string { return sectionRenderOutputSizes() }},
		{"33. Growth Velocity", func() string { return sectionGrowthVelocity() }},
		{"34. Theme Token Usage Audit", func() string { return sectionTokenUsage() }},
		{"35. Eval Memory (peak RSS)", func() string { return sectionEvalMemory(noEvalCost, memEnabled, memHosts, memJSONPath) }},
	}
	var sections []sec
	for i, d := range defs {
		fmt.Fprintf(os.Stderr, "[%d/%d] %s...\n", i+1, len(defs), d.heading)
		content := d.fn()
		fmt.Fprintf(os.Stderr, "[%d/%d] %s done\n", i+1, len(defs), d.heading)
		sections = append(sections, sec{d.heading, content})
	}
	fmt.Fprintf(os.Stderr, "Generating report...\n")
	report := "# angst flake analysis\n\n"
	report += fmt.Sprintf("*Generated: %s*\n\n", time.Now().Format("2006-01-02 15:04"))
	report += "## Table of Contents\n\n"
	for _, s := range sections {
		idx := strings.Index(s.heading, ".")
		rest := s.heading
		if idx >= 0 {
			rest = strings.TrimSpace(s.heading[idx+1:])
		}
		report += fmt.Sprintf("- [%s](#%s)\n", s.heading, slug(rest))
	}
	report += "\n"
	for _, s := range sections {
		if s.content != "" {
			report += s.content
		}
	}
	report += "\n---\n\n*Analysis complete.*\n"

	if outFile != "" {
		if err := os.WriteFile(outFile, []byte(report), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", outFile, err)
			return 1
		}
	} else {
		fmt.Print(report)
	}
	return 0
}
