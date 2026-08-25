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
	patterns := map[string]string{
		"userEnv parsing (parseEnv.nix)": `parseEnv\.nix|userEnv\s*=|builtins\.pathExists.*user\.env`,
		`"x86_64-linux" hardcoded`:        `x86_64-linux`,
		`"proj/angst" hardcoded`:          `proj/angst`,
		`"allowUnfree" hardcoded`:         `allowUnfree`,
	}
	for label, pat := range patterns {
		lines = append(lines, mdSubsection(label))
		files := rgList(pat, false)
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

func sectionCapabilitiesInventory() string {
	lines := []string{mdSection(14, "System Feature Inventory")}
	lines = append(lines, "> **See `nix flake show` for the full list.**\n")
	sysDir := filepath.Join(repoRoot(), "domains", "system")
	if !dirExists(sysDir) {
		return lines[0] + "\n(no domains/system/)"
	}
	caps := sortedDirs(sysDir)
	total := 0
	for _, c := range caps {
		total += len(strings.Split(readNix(filepath.Join(sysDir, c, "system.nix")), "\n"))
	}
	lines = append(lines, fmt.Sprintf("- **%d system features**, %d total LOC\n", len(caps), total))
	for _, c := range caps {
		loc := len(strings.Split(readNix(filepath.Join(sysDir, c, "system.nix")), "\n"))
		lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC", c, loc))
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

func sectionHostInventory() string {
	lines := []string{mdSection(16, "Host Inventory")}
	hostDir := filepath.Join(repoRoot(), "hosts")
	if !dirExists(hostDir) {
		return lines[0] + "\n(no hosts/)"
	}
	for _, host := range sortedDirs(hostDir) {
		hPath := filepath.Join(hostDir, host)
		if !dirExists(hPath) {
			continue
		}
		lines = append(lines, fmt.Sprintf("\n- **%s/**", host))
		for _, f := range globNix(hPath) {
			loc := len(strings.Split(readNix(f), "\n"))
			lines = append(lines, fmt.Sprintf("  - `%s` — %d LOC", filepath.Base(f), loc))
		}
	}
	return strings.Join(lines, "\n")
}
