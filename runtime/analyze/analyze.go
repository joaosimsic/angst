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
	var outFile string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--no-eval-cost":
			noEvalCost = true
		case "--no-graph":
			noGraph = true
		case "-o", "--output":
			if i+1 < len(args) {
				outFile = args[i+1]
				i++
			}
		case "-h", "--help":
			fmt.Print("Usage: analyze [--no-eval-cost] [--no-graph] [-o FILE]\n")
			return 0
		}
	}

	type sec struct {
		heading string
		content string
	}
	sections := []sec{
		{"1. Overview", sectionOverview(noEvalCost)},
		{"2. File Size Heatmap (top 30)", sectionFileSizeHeatmap()},
		{"3. Directory Size Breakdown", sectionDirectoryBreakdown()},
		{"4. Attribute Surface", sectionAttributeSurface()},
		{"5. Configuration Matrix", sectionConfigMatrix()},
		{"6. Domain Feature Coverage", sectionRenderCoverage()},
		{"7. Dependency Fan-in / Fan-out", sectionDependencyFan()},
		{"8. Module Coupling Graph", sectionCouplingGraph(noGraph)},
		{"9. Build Graph Depth", sectionBuildDepth()},
		{"10. Duplication Hotspots", sectionDuplication()},
		{"11. Hardcoded Strings Inventory", sectionHardcodedStrings()},
		{"12. Domain Inventory", sectionDomainInventory()},
		{"13. Theme Inventory", sectionThemeInventory()},
		{"14. System Feature Inventory", sectionCapabilitiesInventory()},
		{"15. Toolchain Inventory", sectionToolchainInventory()},
		{"16. Host Inventory", sectionHostInventory()},
		{"17. Option Inventory", sectionOptionInventory()},
		{"18. Nix Idiom Usage", sectionNixIdiom()},
		{"19. Conditional & Builtins Usage", sectionConditionalBuiltins()},
		{"20. Complexity Metrics", sectionComplexityMetrics()},
		{"21. \"Interesting\" Complexity Metrics", sectionInterestingComplexity()},
		{"22. Error Handling", sectionErrorHandling()},
		{"23. Dead Code", sectionDeadCode()},
		{"24. Anti-Patterns (statix)", sectionAntiPatterns()},
		{"25. Evaluation Cost", sectionEvalCost(noEvalCost)},
		{"26. Technical Debt Score", sectionTechDebt()},
		{"27. Hotspot Table", sectionHotspotTable()},
		{"28. Stability Index", sectionStabilityIndex()},
		{"29. Theme \u00d7 Domain Coverage", sectionThemeDomainCoverage(noEvalCost)},
		{"30. Domain Features", sectionDomainFeatures()},
		{"31. Check Results Breakdown", sectionCheckResults(noEvalCost)},
		{"32. Rendered Output Sizes", sectionRenderOutputSizes()},
		{"33. Growth Velocity", sectionGrowthVelocity()},
		{"34. Theme Token Usage Audit", sectionTokenUsage()},
	}

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
