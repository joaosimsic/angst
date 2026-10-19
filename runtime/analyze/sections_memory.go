package analyze

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const defaultMemHost = "nixos"

func sectionEvalMemory(noEvalCost bool, memEnabled bool, memHosts string, memJSONPath string) string {
	if noEvalCost && !memEnabled {
		return mdSection(35, "Eval Memory (peak RSS)") + "\n> Skipped (`--no-eval-cost` without `--mem`)\n"
	}
	if !memEnabled {
		return mdSection(35, "Eval Memory (peak RSS)") + "\n> Skipped (use `--mem` to measure; `--mem-hosts " + defaultMemHost + ",all`)\n"
	}
	lines := []string{mdSection(35, "Eval Memory (peak RSS)")}
	lines = append(lines, "> Peak RSS via `/usr/bin/time -v` (`Maximum resident set size`), wall time; budget **5 GiB** aggregated (5 hosts), **3 GiB** per-host (`nixos` canary). `nixos` is heaviest (base+desktop+development+embedded, toolchains=\"*\"). `ci` is lean (`ci` profile + `nix` toolchain).\n")

	hostFilter := parseMemHosts(memHosts)
	attrs := buildMemAttrs(hostFilter)
	if len(attrs) == 0 {
		attrs = []string{
			"nixosConfigurations." + defaultMemHost + ".config.system.build.toplevel",
			"checks.x86_64-linux.eval-all",
			"checks.x86_64-linux.build-all",
		}
	}

	var results []memResult
	for i, attr := range attrs {
		fmt.Fprintf(os.Stderr, "  [%d/%d] mem: %s...\n", i+1, len(attrs), attr)
		args := []string{"nix", "eval", ".#" + attr, "--json", "--no-warn-dirty"}
		rc, _, errStr, mem, wall := runWithMem(args, 180*time.Second)
		if errStr != "" && len(errStr) > 400 {
			errStr = errStr[:400]
		}
		results = append(results, memResult{Attr: attr, Rc: rc, MaxRSS: mem, Wall: wall, Err: strings.TrimSpace(errStr)})
		fmt.Fprintf(os.Stderr, "  [%d/%d] mem: %s done %s\n", i+1, len(attrs), attr, formatMiB(mem))
	}

	lines = append(lines, formatMemTable(results))

	lines = append(lines, mdSubsection("Gates (5 GiB aggregated, 3 GiB per-host)"))
	var gateRows [][]any
	limitAgg := 5 * 1024
	limitHost := 3 * 1024
	for _, r := range results {
		limit := limitAgg
		if !strings.HasPrefix(r.Attr, "checks.") && !strings.Contains(r.Attr, "eval-all") && !strings.Contains(r.Attr, "build-all") {
			limit = limitHost
		}
		if strings.HasPrefix(r.Attr, "nixosConfigurations.") {
			limit = limitHost
		}
		gateRows = append(gateRows, []any{fmt.Sprintf("`%s`", r.Attr), gateStatus(r.MaxRSS, limit), formatMiB(r.MaxRSS), fmt.Sprintf("≤%d MiB", limit)})
	}
	lines = append(lines, mdTable([]string{"Attr", "Gate", "maxRSS", "Limit"}, gateRows))

	if memJSONPath != "" {
		lines = append(lines, fmt.Sprintf("\n> Full JSON: `%s`\n", relOf(memJSONPath)))
		if err := writeMemJSON(memJSONPath, results); err != nil {
			lines = append(lines, fmt.Sprintf("\n> _Failed to write JSON: %v_\n", err))
		}
	} else {
		_ = writeMemJSON(filepath.Join(repoRoot(), "analysis-memory.json"), results)
	}

	return strings.Join(lines, "\n")
}

func parseMemHosts(s string) map[string]bool {
	if s == "" {
		s = defaultMemHost
	}
	m := map[string]bool{}
	for _, p := range strings.Split(s, ",") {
		p = strings.TrimSpace(p)
		if p == "all" {
			return map[string]bool{"all": true}
		}
		if p != "" {
			m[p] = true
		}
	}
	if len(m) == 0 {
		m[defaultMemHost] = true
	}
	return m
}

func buildMemAttrs(filter map[string]bool) []string {
	wantAll := filter["all"]
	var attrs []string

	var allNixos, allHome, allChecks []string
	if wantAll {
		allNixos = nixEvalAttrNames("nixosConfigurations")
		allHome = nixEvalAttrNames("homeConfigurations")
		allChecks = nixEvalAttrNames("checks.x86_64-linux")
	} else {
		if filter["checks"] {
			allChecks = nixEvalAttrNames("checks.x86_64-linux")
		}
	}
	choose := func(names []string, prefix string) {
		for _, n := range names {
			if n == "login-shell-valid" || n == "login-shell-invalid" {
				continue
			}
			if !wantAll && strings.HasSuffix(n, "-theme-override-test") {
				continue
			}
			if wantAll || filter[n] {
				attrs = append(attrs, prefix+n)
			}
		}
	}
	if wantAll {
		for _, h := range allNixos {
			attrs = append(attrs, "nixosConfigurations."+h+".config.system.build.toplevel")
		}
		choose(allHome, "homeConfigurations.")
		for i, a := range attrs {
			if strings.HasPrefix(a, "homeConfigurations.") && !strings.HasSuffix(a, ".activationPackage") {
				attrs[i] = a + ".activationPackage"
			}
		}
		for _, c := range []string{"eval-all", "build-all"} {
			for _, n := range allChecks {
				if n == c {
					attrs = append(attrs, "checks.x86_64-linux."+c)
				}
			}
		}
	} else if len(filter) > 0 {
		checkSet := map[string]bool{}
		for _, n := range allChecks {
			checkSet[n] = true
		}
		for h := range filter {
			if h == "checks" || h == "all" {
				continue
			}
			if checkSet[h] {
				continue
			}
			attrs = append(attrs, "nixosConfigurations."+h+".config.system.build.toplevel")
			if h == defaultMemHost {
				attrs = append(attrs, "homeConfigurations."+h+".activationPackage")
			}
		}
		if len(allChecks) > 0 {
			choose(allChecks, "checks.x86_64-linux.")
		}
		if filter["checks"] && len(allChecks) == 0 {
			allChecks = nixEvalAttrNames("checks.x86_64-linux")
			choose(allChecks, "checks.x86_64-linux.")
		}
	}
	seen := map[string]bool{}
	var uniq []string
	for _, a := range attrs {
		if !seen[a] {
			seen[a] = true
			uniq = append(uniq, a)
		}
	}
	sort.Strings(uniq)
	return uniq
}

func writeMemJSON(path string, results []memResult) error {
	data, err := json.MarshalIndent(results, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o644)
}
