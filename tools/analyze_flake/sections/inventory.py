"""Sections 10-16: duplication, hardcoded strings, domain/theme/cap/toolchain/host inventory."""

from pathlib import Path
from typing import Any

from ..util import REPO, md_section, md_subsection, md_table, read_nix, rg, run


def section_duplication() -> str:
    """Section 10: Duplication Hotspots."""
    lines = [md_section(10, "Duplication Hotspots")]

    patterns = {
        "userEnv parsing (parseEnv.nix)": (
            r"parseEnv\.nix|userEnv\s*=|builtins\.pathExists.*user\.env"
        ),
        '"x86_64-linux" hardcoded': r"x86_64-linux",
        '"proj/angst" hardcoded': r"proj/angst",
        '"allowUnfree" hardcoded': r"allowUnfree",
    }

    for label, pat in patterns.items():
        lines.append(md_subsection(label))
        rc, out, _ = rg(["-l", pat], timeout=30)
        if rc == 0 and out.strip():
            for f in out.strip().splitlines():
                lines.append(f"- `{f}`")
        else:
            lines.append("_(none found)_")

    lines.append(md_subsection("Key re-imports (dedup candidates)"))
    for pat in ("parseEnv", "domains/default", "themes/default", "shared.nix"):
        rc, out, _ = rg(["-l", pat], timeout=15)
        count = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
        if count > 1:
            lines.append(f"- **{pat}**: {count} files import it")
            for f in out.strip().splitlines():
                lines.append(f"  - `{f}`")
    return "\n".join(lines)


def section_hardcoded_strings() -> str:
    """Section 11: Hardcoded Strings Inventory."""
    lines = [md_section(11, "Hardcoded Strings Inventory")]
    pairs = [
        ("angst", "project name"),
        ("ANGST", "env var prefix"),
        ("nixpkgs", "flake input"),
        ("home-manager", "flake input"),
        ("proj/angst", "repo path"),
        ("x86_64", "architecture"),
        ("allowUnfree", "nixpkgs config"),
        ("generic", "default host"),
        ("monochrome", "default theme"),
        ("NIX_", "nix env vars"),
        ("ANGST_", "angst env vars"),
    ]
    rows: list[list[Any]] = []
    for s, desc in pairs:
        rc, out, _ = rg(["-cF", s], timeout=15)
        total = 0
        if rc == 0 and out.strip():
            for line in out.strip().splitlines():
                if ":" in line:
                    total += int(line.split(":", 1)[1])
        rc2, out2, _ = rg(["-lF", s], timeout=15)
        files = len(out2.strip().splitlines()) if rc2 == 0 and out2.strip() else 0
        rows.append([f'"{s}"', total, files, desc])
    lines.append(md_table(["String", "Occurrences", "Files", "Description"], rows))
    return "\n".join(lines)


def section_domain_inventory_condensed() -> str:
    """Section 12: Domain Inventory."""
    lines = [md_section(12, "Domain Inventory")]
    rows: list[list[Any]] = []
    domains_path = REPO / "domains"
    if not domains_path.is_dir():
        return lines[0] + "\n(no domains/)"
    for cat in sorted(domains_path.iterdir()):
        if not cat.is_dir():
            continue
        doms = sorted(d.name for d in cat.iterdir() if d.is_dir())
        cat_loc = sum(
            len(read_nix(f).splitlines())
            for d in cat.iterdir()
            if d.is_dir()
            for f in d.rglob("*.nix")
            if ".git" not in f.parts
        )
        rows.append(
            [cat.name, len(doms), ",".join(doms), cat_loc]
        )
    if rows:
        lines.append(
            md_table(["Category", "Domains", "Names", "LOC"], rows)
        )
    return "\n".join(lines)


def section_theme_inventory_condensed() -> str:
    """Section 13: Theme Inventory."""
    lines = [md_section(13, "Theme Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    themes_dir = REPO / "themes"
    if not themes_dir.is_dir():
        return lines[0] + "\n(no themes/)"
    themes = sorted(
        f.stem for f in themes_dir.glob("*.nix") if f.stem not in ("default", "schema")
    )
    total_loc = sum(
        len(read_nix(f).splitlines())
        for f in themes_dir.glob("*.nix")
        if f.stem not in ("default", "schema")
    )
    lines.append(f"- **{len(themes)} themes**, {total_loc} total LOC\n")
    for t in themes:
        loc = len(read_nix(themes_dir / f"{t}.nix").splitlines())
        default_mark = " (default)" if t == "monochrome" else ""
        lines.append(f"  - `{t}` — {loc} LOC{default_mark}")
    return "\n".join(lines)


def section_capabilities_inventory_condensed() -> str:
    """Section 14: System Feature Inventory (domains/system)."""
    lines = [md_section(14, "System Feature Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    sys_dir = REPO / "domains" / "system"
    if not sys_dir.is_dir():
        return lines[0] + "\n(no domains/system/)"
    caps = sorted(p.name for p in sys_dir.iterdir() if p.is_dir())
    total_loc = sum(
        len(read_nix(p / "system.nix").splitlines())
        for p in (sys_dir / c for c in caps)
    )
    lines.append(f"- **{len(caps)} system features**, {total_loc} total LOC\n")
    for c in caps:
        loc = len(read_nix(sys_dir / c / "system.nix").splitlines())
        lines.append(f"  - `{c}` — {loc} LOC")
    return "\n".join(lines)


def section_toolchain_inventory_condensed() -> str:
    """Section 15: Toolchain Inventory."""
    lines = [md_section(15, "Toolchain Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    tc_dir = REPO / "toolchains"
    if not tc_dir.is_dir():
        return lines[0] + "\n(no toolchains/)"
    tcs = sorted(f.stem for f in tc_dir.glob("*.nix") if f.stem != "default")
    total_loc = sum(
        len(read_nix(f).splitlines())
        for f in tc_dir.glob("*.nix")
        if f.stem != "default"
    )
    lines.append(f"- **{len(tcs)} toolchains**, {total_loc} total LOC\n")
    for t in tcs:
        loc = len(read_nix(tc_dir / f"{t}.nix").splitlines())
        lines.append(f"  - `{t}` — {loc} LOC")
    return "\n".join(lines)


def section_host_inventory() -> str:
    """Section 16: Host Inventory."""
    lines = [md_section(16, "Host Inventory")]
    host_dir = REPO / "hosts"
    if not host_dir.is_dir():
        return lines[0] + "\n(no hosts/)"
    for host in sorted(host_dir.iterdir()):
        if not host.is_dir():
            continue
        lines.append(f"\n- **{host.name}/**")
        for f in sorted(host.glob("*.nix")):
            loc = len(read_nix(f).splitlines())
            lines.append(f"  - `{f.name}` — {loc} LOC")
    return "\n".join(lines)
