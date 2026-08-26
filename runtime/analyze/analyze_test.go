package analyze

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

var expectedHeadings = []string{
	"1. Overview",
	"2. File Size Heatmap (top 30)",
	"3. Directory Size Breakdown",
	"4. Attribute Surface",
	"5. Configuration Matrix",
	"6. Domain Feature Coverage",
	"7. Dependency Fan-in / Fan-out",
	"8. Module Coupling Graph",
	"9. Build Graph Depth",
	"10. Duplication Hotspots",
	"11. Hardcoded Strings Inventory",
	"12. Domain Inventory",
	"13. Theme Inventory",
	"14. System Feature Inventory",
	"15. Toolchain Inventory",
	"16. Host Inventory",
	"17. Option Inventory",
	"18. Nix Idiom Usage",
	"19. Conditional & Builtins Usage",
	"20. Complexity Metrics",
	"21. \"Interesting\" Complexity Metrics",
	"22. Error Handling",
	"23. Dead Code",
	"24. Anti-Patterns (statix)",
	"25. Evaluation Cost",
	"26. Technical Debt Score",
	"27. Hotspot Table",
	"28. Stability Index",
	"29. Theme \u00d7 Domain Coverage",
	"30. Domain Features",
	"31. Check Results Breakdown",
	"32. Rendered Output Sizes",
	"33. Growth Velocity",
	"34. Theme Token Usage Audit",
	"35. Eval Memory (peak RSS)",
}

func TestAnalyzeHeadings(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "analysis.md")
	if rc := Run([]string{"--no-eval-cost", "--no-graph", "-o", out}); rc != 0 {
		t.Fatalf("Run returned %d", rc)
	}
	data, err := os.ReadFile(out)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}
	text := string(data)
	re := regexp.MustCompile(`(?m)^## \d+\. .+`)
	matches := re.FindAllString(text, -1)
	if len(matches) != 35 {
		t.Fatalf("expected 35 sections, got %d: %v", len(matches), matches)
	}
	for i, h := range expectedHeadings {
		want := "## " + h
		if !strings.Contains(matches[i], want) {
			t.Errorf("section %d heading mismatch: got %q, want %q", i+1, matches[i], want)
		}
	}
}

func TestAnalyzeNoGraphFlag(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "analysis.md")
	if rc := Run([]string{"--no-graph", "--no-eval-cost", "-o", out}); rc != 0 {
		t.Fatalf("Run returned %d", rc)
	}
	data, _ := os.ReadFile(out)
	if strings.Contains(string(data), "```mermaid") {
		t.Error("expected no mermaid graph with --no-graph")
	}
}
