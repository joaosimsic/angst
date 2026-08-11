"""Sections 30-35: theme×domain coverage, features, checks, render sizes, growth, tokens."""

import re
import time
from pathlib import Path
from typing import Any

from ..util import (
    REPO,
    has_cmd,
    md_code,
    md_section,
    md_subsection,
    md_table,
    nix_eval_attr_names,
    read_nix,
    run,
)


def _discover_domains() -> list[Path]:
    """Return sorted list of domain directories that exist under domains/."""
    result: list[Path] = []
    domains_path = REPO / "domains"
    if not domains_path.is_dir():
        return result
    for cat in sorted(domains_path.iterdir()):
        if not cat.is_dir():
            continue
        for d in sorted(cat.iterdir()):
            if d.is_dir():
                result.append(d)
    return result


def _domain_name(d: Path) -> str:
    """Return the domain name as category/name from its path."""
    rel = d.relative_to(REPO)
    parts = rel.parts
    if len(parts) >= 3 and parts[0] == "domains":
        return f"{parts[1]}/{parts[2]}"
    return str(rel)


def _discover_themes() -> list[str]:
    """Return sorted list of theme names, excluding default/schema."""
    themes_dir = REPO / "themes"
    if not themes_dir.is_dir():
        return []
    return sorted(
        f.stem for f in themes_dir.glob("*.nix") if f.stem not in ("default", "schema")
    )


def _domain_from_render_path(output_path: str) -> str | None:
    """Extract domain name from a render output path."""
    m = re.match(r"domains/([^/]+/[^/]+)/", output_path)
    return m.group(1) if m else None


def _domain_from_error(err: str) -> str | None:
    """Extract domain name from an error message."""
    m = re.search(r"domains/([^/]+/[^/]+)/", err)
    return m.group(1) if m else None


def section_theme_domain_coverage(no_eval_cost: bool = False) -> str:
    """Section 30: Theme × Domain Coverage."""
    lines = [md_section(30, "Theme × Domain Coverage")]
    lines.append("> ✓ = render produces output, ✗ = render throws, — = no render.nix\n")

    if no_eval_cost:
        lines.append("> Skipped (`--no-eval-cost`)\n")
        return "\n".join(lines)

    themes = _discover_themes()
    if not themes:
        lines.append("(no themes)")
        return "\n".join(lines)

    all_domains = _discover_domains()
    domain_names = [_domain_name(d) for d in all_domains]
    render_domains = [d for d in all_domains if (d / "render.nix").exists()]
    render_domain_names = {_domain_name(d) for d in render_domains}

    if not render_domains:
        lines.append("(no domains with render.nix)")
        return "\n".join(lines)

    matrix: dict[str, dict[str, str]] = {}

    for theme in themes:
        matrix[theme] = {}
        for dn in domain_names:
            if dn in render_domain_names:
                matrix[theme][dn] = "?"
            else:
                matrix[theme][dn] = "—"

        rc, out, err = run(
            [
                "nix",
                "eval",
                "--apply",
                f'f: f "generic" "{theme}"',
                "--raw",
                ".#lib.renderDomainOutputPathsFor",
                "--no-warn-dirty",
            ],
            timeout=30,
        )

        if rc == 0 and out.strip():
            covered = set()
            for p in out.strip().splitlines():
                dn = _domain_from_render_path(p.strip())
                if dn:
                    covered.add(dn)
            for dn in render_domain_names:
                matrix[theme][dn] = "✓" if dn in covered else "✗"
        else:
            failing = _domain_from_error(err) if err else None
            for dn in render_domain_names:
                if failing and dn == failing:
                    matrix[theme][dn] = "✗"
                else:
                    matrix[theme][dn] = ""

    headers = ["Theme"] + domain_names
    rows: list[list[Any]] = []
    for theme in sorted(themes):
        row: list[Any] = [f"`{theme}`"]
        for dn in domain_names:
            v = matrix[theme].get(dn, "—")
            row.append(v)
        rows.append(row)

    lines.append(md_table(headers, rows))
    return "\n".join(lines)


def section_domain_features() -> str:
    """Section 31: Domain Features."""
    lines = [md_section(31, "Domain Features")]
    lines.append("> Which optional features each domain provides.\n")

    all_domains = _discover_domains()
    if not all_domains:
        lines.append("(no domains)")
        return "\n".join(lines)

    rows: list[list[Any]] = []
    for d in all_domains:
        dn = _domain_name(d)
        rows.append(
            [
                dn,
                "✓" if (d / "render.nix").exists() else "—",
                "✓" if (d / "nixos.nix").exists() else "—",
                "✓" if (d / "config").is_dir() else "—",
                "✓" if (d / "module.nix").exists() else "—",
            ]
        )

    rows.sort(key=lambda r: str(r[0]))
    lines.append(
        md_table(
            ["Domain", "render", "nixos", "config/", "module"],
            rows,
        )
    )
    return "\n".join(lines)


def section_check_results(no_eval_cost: bool = False) -> str:
    """Section 32: Check Results Breakdown."""
    lines = [md_section(32, "Check Results Breakdown")]

    if no_eval_cost:
        lines.append("> Skipped (`--no-eval-cost`)\n")
        return "\n".join(lines)

    check_names = nix_eval_attr_names("checks.x86_64-linux")
    if not check_names:
        lines.append("_(no checks found)_")
        return "\n".join(lines)

    pass_count = 0
    fail_count = 0
    rows: list[list[Any]] = []

    for name in sorted(check_names):
        start = time.perf_counter()
        rc, out, err = run(
            [
                "nix",
                "build",
                "--no-link",
                f".#checks.x86_64-linux.{name}",
                "--no-warn-dirty",
            ],
            timeout=90,
        )
        elapsed = time.perf_counter() - start
        status = "✓" if rc == 0 else "✗"
        detail = ""
        if rc != 0:
            fail_count += 1
            combined = (out + "\n" + err).strip()
            if combined:
                short = combined[:300].replace("\n", " ")
                detail = short
        else:
            pass_count += 1
        rows.append([f"`{name}`", status, f"{elapsed:.2f}s", detail])

    lines.append(md_table(["Check", "Result", "Time", "Details"], rows))
    lines.append(f"\n**{pass_count} passed, {fail_count} failed**\n")

    rc, out, _ = run(
        ["nix", "eval", ".#lib.themeLint", "--raw", "--no-warn-dirty"],
        timeout=30,
    )
    if rc == 0 and out.strip():
        lines.append(md_subsection("Theme lint detail"))
        lines.append(md_code(out.strip()))
    else:
        lines.append(md_subsection("Theme lint detail"))
        lines.append("_(could not evaluate themeLint)_\n")

    return "\n".join(lines)


def _count_render_output_lines(render_path: Path) -> tuple[int, int]:
    """Estimate number of output files and lines from a render.nix."""
    text = read_nix(render_path)
    file_count = 0
    total_lines = 0

    in_block = False
    block_lines = 0
    openers_seen = 0

    for line in text.splitlines():
        stripped = line.strip()

        if not in_block:
            if re.search(r"=\s*''\s*$", stripped):
                in_block = True
                block_lines = 0
                openers_seen += 1
                continue

        if in_block:
            if re.match(r"''\s*[;\]})@]?\s*$", stripped):
                in_block = False
                total_lines += block_lines
                continue
            block_lines += 1

    file_count = len(re.findall(r'path\s*=\s*"[^"]+"', text))
    return file_count, total_lines


def section_render_output_sizes() -> str:
    """Section 33: Rendered Output Sizes."""
    lines = [md_section(33, "Rendered Output Sizes")]
    lines.append(
        "> Estimated output lines from multi-line string literals in render.nix.\n"
    )

    all_domains = _discover_domains()
    render_domains = [
        (d, _domain_name(d)) for d in all_domains if (d / "render.nix").exists()
    ]

    if not render_domains:
        lines.append("(no domains with render.nix)")
        return "\n".join(lines)

    rows: list[list[Any]] = []
    for d, dn in render_domains:
        file_count, total_lines = _count_render_output_lines(d / "render.nix")
        rows.append([dn, file_count, total_lines])

    rows.sort(key=lambda r: -r[2])
    lines.append(md_table(["Domain", "Output files", "Est. output lines"], rows))
    return "\n".join(lines)


def section_growth_velocity() -> str:
    """Section 34: Growth Velocity."""
    lines = [md_section(34, "Growth Velocity")]
    lines.append(
        "> Monthly lines added/removed across .nix, .sh, and .rs files (excludes merges).\n"
    )

    if not has_cmd("git"):
        lines.append("> `git` not found.\n")
        return "\n".join(lines)

    rc, out, _ = run(
        [
            "git",
            "log",
            "--since=12 months ago",
            "--format=COMMIT %ai",
            "--numstat",
            "--no-merges",
            "--",
            "*.nix",
            "*.sh",
            "*.rs",
        ],
        timeout=60,
    )

    if rc != 0 or not out.strip():
        lines.append("> No commit history found.\n")
        return "\n".join(lines)

    monthly: dict[str, dict] = {}
    current_month: str | None = None

    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("COMMIT "):
            date_str = line.split(maxsplit=1)[1].strip()
            current_month = date_str[:7]
            if current_month not in monthly:
                monthly[current_month] = {"added": 0, "removed": 0, "commits": 0}
            monthly[current_month]["commits"] += 1
            continue
        if current_month is not None and "\t" in line:
            parts = line.split("\t")
            if len(parts) >= 2:
                try:
                    added = int(parts[0]) if parts[0] != "-" else 0
                    removed = int(parts[1]) if parts[1] != "-" else 0
                    monthly[current_month]["added"] += added
                    monthly[current_month]["removed"] += removed
                except ValueError:
                    pass

    if not monthly:
        lines.append("> No commit history found.\n")
        return "\n".join(lines)

    rows: list[list[Any]] = []
    total_added = 0
    total_removed = 0
    for month in sorted(monthly.keys()):
        m = monthly[month]
        net = m["added"] - m["removed"]
        total_added += m["added"]
        total_removed += m["removed"]
        rows.append(
            [
                month,
                m["added"],
                m["removed"],
                f"+{net}" if net >= 0 else str(net),
                m["commits"],
            ]
        )

    lines.append(md_table(["Month", "Added", "Removed", "Net", "Commits"], rows))
    total_net = total_added - total_removed
    lines.append(
        f"\n> **12-month totals:** +{total_added} added, −{total_removed} removed,"
        f" net {total_net:+d}"
    )
    return "\n".join(lines)


_TOKEN_DEFS: list[tuple[str, str]] = [
    ("palette.bg.base", r"p\.background\.base\b|t\.safe\.foregroundOnBackground\b"),
    ("palette.bg.variant", r"p\.background\.variant\b"),
    ("palette.sf.base", r"p\.surface\.base\b|t\.safe\.foregroundOnSurfaceBase\b"),
    (
        "palette.sf.variant",
        r"p\.surface\.variant\b|t\.safe\.foregroundOnSurfaceVariant\b",
    ),
    ("palette.fg.base", r"p\.foreground\.base\b"),
    (
        "palette.fg.variant",
        r"p\.foreground\.variant\b|t\.safe\.\w*OnForegroundVariant\b",
    ),
    ("palette.ac.base", r"p\.accent\.base\b"),
    (
        "palette.ac.variant",
        r"p\.accent\.variant\b|t\.safe\.foregroundOnAccentVariant\b",
    ),
    ("palette.dim", r"p\.dim\b"),
    ("ansi.error", r"\bt\.ansi\.error\b|\ba\.error\b"),
    ("ansi.warn", r"\bt\.ansi\.warn\b|\ba\.warn\b"),
    ("ansi.info", r"\bt\.ansi\.info\b|\ba\.info\b"),
    ("ansi.success", r"\bt\.ansi\.success\b|\ba\.success\b"),
]


def _token_counts(render_path: Path) -> dict[str, int]:
    """Count theme token references in a render.nix file."""
    text = read_nix(render_path)
    result: dict[str, int] = {}
    for token_name, pattern in _TOKEN_DEFS:
        result[token_name] = len(re.findall(pattern, text))
    return result


def section_token_usage() -> str:
    """Section 35: Theme Token Usage Audit."""
    lines = [md_section(35, "Theme Token Usage Audit")]
    lines.append(
        "> How many times each schema token is referenced in each render.nix.\n"
    )
    lines.append(
        "> Token lookup uses regex patterns covering `${p.xxx}`, `${t.safe.xxx}`,"
        " `${a.xxx}`, and `${t.ansi.xxx}` references.\n"
    )

    all_domains = _discover_domains()
    render_domains = [
        (d, _domain_name(d)) for d in all_domains if (d / "render.nix").exists()
    ]

    if not render_domains:
        lines.append("(no domains with render.nix)")
        return "\n".join(lines)

    token_names = [t[0] for t in _TOKEN_DEFS]
    short_names = [tn.replace("palette.", "").replace(".", "·") for tn in token_names]

    rows: list[list[Any]] = []
    domain_usage: dict[str, dict[str, int]] = {}
    token_totals: dict[str, int] = {tn: 0 for tn in token_names}
    token_domain_counts: dict[str, int] = {tn: 0 for tn in token_names}

    for d, dn in render_domains:
        counts = _token_counts(d / "render.nix")
        domain_usage[dn] = counts
        row: list[Any] = [dn]
        for tn in token_names:
            c = counts.get(tn, 0)
            row.append(c if c > 0 else "—")
            token_totals[tn] += c
            if c > 0:
                token_domain_counts[tn] += 1
        rows.append(row)

    headers = ["Domain"] + short_names
    lines.append(md_subsection("Per-domain usage"))
    lines.append(md_table(headers, rows))

    lines.append(md_subsection("Token popularity summary"))
    summary_rows: list[list[Any]] = []
    for tn in token_names:
        summary_rows.append(
            [
                f"`{tn}`",
                token_totals[tn],
                token_domain_counts[tn],
            ]
        )
    summary_rows.sort(key=lambda r: (-r[1], r[0]))
    lines.append(md_table(["Token", "Total uses", "Used by (domains)"], summary_rows))

    return "\n".join(lines)
