"""Sections 27-28: hotspot table, stability index."""

import re
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

from ..util import (
    REPO,
    find_nix_files,
    md_section,
    md_subsection,
    md_table,
    parse_imports_from_tree,
    read_nix,
    run,
)


def section_hotspot_table() -> str:
    """Section 27: Hotspot Table."""
    lines = [md_section(27, "Hotspot Table")]
    lines.append(
        "> Cross-references file size, git churn, dependency counts,"
        " and complexity into a single view.\n"
    )
    lines.append(
        "> **Columns**: LOC (size), Churn (commits/year), Imports (fan-out), Dependents (fan-in),"
    )
    lines.append(
        "> Complexity (derived from nesting depth, string interpolation, conditional count).\n"
    )

    files = find_nix_files()
    fan_out, fan_in = parse_imports_from_tree(files)

    rc, out, _ = run(
        [
            "git",
            "log",
            "--oneline",
            "--since=1 year ago",
            "--name-only",
            "--",
            "*.nix",
            "*.sh",
            "*.rs",
        ],
        timeout=30,
    )
    churn: Counter = Counter()
    if rc == 0:
        for line in out.splitlines():
            line = line.strip()
            if not line or line[0].isdigit() or line.startswith("commit "):
                continue
            churn[line] += 1

    def complexity_score(filepath: Path) -> tuple[str, int, str]:
        """Compute a complexity label, score, and reason string for a file."""
        text = read_nix(filepath)
        score = 0
        reasons: list[str] = []
        depth = 0
        maxdepth = 0
        for line in text.splitlines():
            s = line.strip()
            if s.startswith("let ") or s == "let":
                depth += 1
                maxdepth = max(maxdepth, depth)
            elif s.startswith("in ") or s == "in":
                depth = max(0, depth - 1)
        if maxdepth >= 3:
            score += 3
            reasons.append(f"depth={maxdepth}")
        elif maxdepth >= 2:
            score += 1
            reasons.append(f"depth={maxdepth}")
        interp = len(re.findall(r"\$\{", text))
        if interp > 30:
            score += 3
            reasons.append(f"interp={interp}")
        elif interp > 15:
            score += 2
            reasons.append(f"interp={interp}")
        elif interp > 5:
            score += 1
            reasons.append(f"interp={interp}")
        cond = len(re.findall(r"mkIf|mkDefault|mkForce", text))
        if cond > 10:
            score += 3
            reasons.append(f"cond={cond}")
        elif cond > 5:
            score += 2
            reasons.append(f"cond={cond}")
        elif cond > 2:
            score += 1
            reasons.append(f"cond={cond}")
        loc = len(text.splitlines())
        if loc > 300:
            score += 3
            reasons.append(f"LOC={loc}")
        elif loc > 150:
            score += 2
            reasons.append(f"LOC={loc}")
        elif loc > 80:
            score += 1
            reasons.append(f"LOC={loc}")

        if score >= 7:
            label = "Very High"
        elif score >= 5:
            label = "High"
        elif score >= 3:
            label = "Medium"
        elif score >= 1:
            label = "Low"
        else:
            label = "Minimal"
        return label, score, ", ".join(reasons)

    rows: list[list[Any]] = []
    for f in files:
        rel = str(f.relative_to(REPO))
        loc = len(read_nix(f).splitlines())
        ch = churn.get(rel, 0)
        im = len(fan_out.get(f, []))
        de = fan_in.get(f, 0)
        cx_label, cx_score, _cx_reason = complexity_score(f)
        rows.append([f"`{rel}`", loc, ch, im, de, f"{cx_label}", cx_score])

    rows.sort(key=lambda r: (-r[1], -r[2]))
    header = ["File", "LOC", "Churn", "Imports", "Dependents", "Complexity", "Score"]
    lines.append(md_table(header, rows[:25]))
    return "\n".join(lines)


def section_stability_index() -> str:
    """Section 28: Stability Index."""
    lines = [md_section(28, "Stability Index")]
    lines.append(
        "> Cross-references git churn with file recency. **Hot** = high churn + recently modified,"
        " **Active** = moderate churn, **Stable** = low churn,"
        " **Archived** = no changes in 6+ months.\n"
    )

    rc2, out2, _ = run(
        [
            "git",
            "log",
            "--oneline",
            "--since=2 years ago",
            "--format=%H %ai",
            "--",
            "*.nix",
        ],
        timeout=30,
    )
    date_by_commit: dict[str, str] = {}
    if rc2 == 0:
        for line in out2.strip().splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2:
                date_by_commit[parts[0]] = parts[1]

    churn: Counter = Counter()
    file_last_date: dict[str, str] = {}
    rc3, out3, _ = run(
        [
            "git",
            "log",
            "--oneline",
            "--since=2 years ago",
            "--format=%H",
            "--name-only",
            "--",
            "*.nix",
        ],
        timeout=30,
    )
    current_hash = ""
    if rc3 == 0:
        for line in out3.splitlines():
            line = line.strip()
            if not line:
                continue
            if re.match(r"^[0-9a-f]{7,40}$", line):
                current_hash = line
                continue
            if line in churn:
                churn[line] += 1
            else:
                churn[line] = 1
            if (
                current_hash
                and line not in file_last_date
                and current_hash in date_by_commit
            ):
                file_last_date[line] = date_by_commit[current_hash]

    now = datetime.now()
    rows: list[list[Any]] = []
    for f in find_nix_files():
        rel = str(f.relative_to(REPO))
        ch = churn.get(rel, 0)
        last_date_str = file_last_date.get(rel, "")
        last_date = None
        if last_date_str:
            try:
                last_date = datetime.strptime(last_date_str[:10], "%Y-%m-%d")
            except ValueError:
                pass

        if last_date:
            days_ago = (now - last_date).days
        else:
            days_ago = 999

        if ch >= 10 and days_ago < 60:
            label = "Hot"
        elif ch >= 5 and days_ago < 180:
            label = "Active"
        elif ch >= 1:
            label = "Stable"
        else:
            label = "Archived"

        if last_date_str:
            date_short = (
                last_date_str[:10] if len(last_date_str) >= 10 else last_date_str
            )
            rows.append([f"`{rel}`", ch, date_short, label])
        elif ch > 0:
            rows.append([f"`{rel}`", ch, "(no date)", label])

    rows.sort(key=lambda r: (-r[1], r[2] if len(r) > 2 else ""))
    lines.append(md_table(["File", "Churn", "Last changed", "Label"], rows[:20]))
    return "\n".join(lines)
