package analyze

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func sectionDuplication() string {
	lines := []string{mdSection(10, "Duplication Hotspots")}
	patterns := []struct {
		label string
		pat   string
	}{
		{"userEnv parsing (parseEnv.nix)", `parseEnv\.nix|userEnv\s*=|builtins\.pathExists.*user\.env`},
		{`"x86_64-linux" hardcoded`, `x86_64-linux`},
		{`"proj/angst" hardcoded`, `proj/angst`},
		{`"allowUnfree" hardcoded`, `allowUnfree`},
	}
	for _, p := range patterns {
		lines = append(lines, mdSubsection(p.label))
		files := rgList(p.pat, false)
		sort.Strings(files)
		if len(files) > 0 {
			for _, f := range files {
				lines = append(lines, fmt.Sprintf("- `%s`", f))
			}
		} else {
			lines = append(lines, "_(none found)_")
		}
	}
	lines = append(lines, mdSubsection("Key re-imports (dedup candidates)"))
	for _, pat := range []string{"parseEnv", "domains/default", "themes/default", "shared.nix"} {
		files := rgList(pat, false)
		if len(files) > 1 {
			lines = append(lines, fmt.Sprintf("- **%s**: %d files import it", pat, len(files)))
			for _, f := range files {
				lines = append(lines, fmt.Sprintf("  - `%s`", f))
			}
		}
	}
	return strings.Join(lines, "\n")
}

func sectionHardcodedStrings() string {
	lines := []string{mdSection(11, "Hardcoded Strings Inventory")}
	pairs := [][]string{
		{"angst", "project name"},
		{"ANGST", "env var prefix"},
		{"nixpkgs", "flake input"},
		{"home-manager", "flake input"},
		{"proj/angst", "repo path"},
		{"x86_64", "architecture"},
		{"allowUnfree", "nixpkgs config"},
		{"generic", "default host"},
		{"monochrome", "default theme"},
		{"NIX_", "nix env vars"},
		{"ANGST_", "angst env vars"},
	}
	rows := [][]any{}
	for _, p := range pairs {
		s := p[0]
		total := rgCount(s, true)
		files := len(rgList(s, true))
		rows = append(rows, []any{fmt.Sprintf("\"%s\"", s), total, files, p[1]})
	}
	lines = append(lines, mdTable([]string{"String", "Occurrences", "Files", "Description"}, rows))
	return strings.Join(lines, "\n")
}

func sectionDomainInventory() string {
	lines := []string{mdSection(12, "Domain Inventory")}
	domainsPath := filepath.Join(repoRoot(), "domains")
	if !dirExists(domainsPath) {
		return lines[0] + "\n(no domains/)"
	}
	rows := [][]any{}
	for _, cat := range sortedDirs(domainsPath) {
		catPath := filepath.Join(domainsPath, cat)
		if !dirExists(catPath) {
			continue
		}
		doms := sortedDirs(catPath)
		catLoc := 0
		for _, d := range doms {
			dPath := filepath.Join(catPath, d)
			_ = filepath.Walk(dPath, func(p string, info os.FileInfo, err error) error {
				if err == nil && !info.IsDir() && filepath.Ext(p) == ".nix" {
					catLoc += len(strings.Split(readNix(p), "\n"))
				}
				return nil
			})
		}
		rows = append(rows, []any{cat, len(doms), strings.Join(doms, ","), catLoc})
	}
	if len(rows) > 0 {
		lines = append(lines, mdTable([]string{"Category", "Domains", "Names", "LOC"}, rows))
	}
	return strings.Join(lines, "\n")
}

func sectionThemeInventory() string {
	lines := []string{mdSection(13, "Theme Inventory")}
	lines = append(lines, "> **See `nix flake show` for the full list.**\n")
	themesDir := filepath.Join(repoRoot(), "themes")
	if !dirExists(themesDir) {
		return lines[0] + "\n(no themes/)"
	}
	themes := discoverThemes()
	total := 0
	for _, t := range themes {
		total += len(strings.Split(readNix(filepath.Join(themesDir, t+".nix")), "\n"))
	}
	lines = append(lines, fmt.Sprintf("- **%d themes**, %d total LOC\n", len(themes), total))
	for _, t := range themes {
		loc := len(strings.Split(readNix(filepath.Join(themesDir, t+".nix")), "\n"))
		defaultMark := ""
		if t == "monochrome" {
			defaultMark = " (default)"
		}
		lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC%s", t, loc, defaultMark))
	}
	return strings.Join(lines, "\n")
}

func sectionKernelInventory() string {
	lines := []string{mdSection(14, "Kernel Feature Inventory")}
	lines = append(lines, "> **See `nix flake show` for the full list.**\n")
	var feats []string
	var locs []int
	total := 0
	for _, cat := range []string{"kernel", "display"} {
		catDir := filepath.Join(repoRoot(), "domains", cat)
		if !dirExists(catDir) {
			continue
		}
		for _, name := range sortedDirs(catDir) {
			p := filepath.Join(catDir, name, "system.nix")
			if !fileExists(p) {
				continue
			}
			feats = append(feats, cat+"/"+name)
			loc := len(strings.Split(readNix(p), "\n"))
			locs = append(locs, loc)
			total += loc
		}
	}
	if len(feats) == 0 {
		return lines[0] + "\n(no kernel/display features)"
	}
	lines = append(lines, fmt.Sprintf("- **%d kernel features**, %d total LOC\n", len(feats), total))
	for i, c := range feats {
		lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC", c, locs[i]))
	}
	return strings.Join(lines, "\n")
}

func sectionToolchainInventory() string {
	lines := []string{mdSection(15, "Toolchain Inventory")}
	lines = append(lines, "> **See `nix flake show` for the full list.**\n")
	tcDir := filepath.Join(repoRoot(), "toolchains")
	if !dirExists(tcDir) {
		return lines[0] + "\n(no toolchains/)"
	}
	var tcs []string
	total := 0
	for _, f := range globNix(tcDir) {
		name := strings.TrimSuffix(filepath.Base(f), ".nix")
		if name == "default" {
			continue
		}
		tcs = append(tcs, name)
		total += len(strings.Split(readNix(f), "\n"))
	}
	sort.Strings(tcs)
	lines = append(lines, fmt.Sprintf("- **%d toolchains**, %d total LOC\n", len(tcs), total))
	for _, t := range tcs {
		loc := len(strings.Split(readNix(filepath.Join(tcDir, t+".nix")), "\n"))
		lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC", t, loc))
	}
	return strings.Join(lines, "\n")
}

func discoverHostDirs() []string {
	var out []string
	hostRoot := filepath.Join(repoRoot(), "hosts")
	if !dirExists(hostRoot) {
		return out
	}
	var walk func(dir string)
	walk = func(dir string) {
		if fileExists(filepath.Join(dir, "default.nix")) {
			rel, _ := filepath.Rel(hostRoot, dir)
			out = append(out, rel)
			return
		}
		for _, e := range sortedDirs(dir) {
			sub := filepath.Join(dir, e)
			if dirExists(sub) {
				walk(sub)
			}
		}
	}
	for _, top := range sortedDirs(hostRoot) {
		walk(filepath.Join(hostRoot, top))
	}
	sort.Strings(out)
	return out
}

func sectionHostInventory() string {
	lines := []string{mdSection(16, "Host Inventory")}
	hostDir := filepath.Join(repoRoot(), "hosts")
	if !dirExists(hostDir) {
		return lines[0] + "\n(no hosts/)"
	}
	hosts := discoverHostDirs()
	if len(hosts) == 0 {
		return lines[0] + "\n(no hosts found)"
	}
	for _, rel := range hosts {
		hPath := filepath.Join(hostDir, rel)
		lines = append(lines, fmt.Sprintf("\n- **%s/**", rel))
		seen := map[string]bool{}
		for _, f := range globNix(hPath) {
			base := filepath.Base(f)
			if seen[base] {
				continue
			}
			seen[base] = true
			loc := len(strings.Split(readNix(f), "\n"))
			lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC", base, loc))
		}
		if !seen["hardware.nix"] && fileExists(filepath.Join(hPath, "hardware.nix")) {
			loc := len(strings.Split(readNix(filepath.Join(hPath, "hardware.nix")), "\n"))
			lines = append(lines, fmt.Sprintf("  - `hardware.nix` — %d LOC", loc))
		}
	}
	return strings.Join(lines, "\n")
}
