"""Sections 17-22: option inventory, idioms, conditionals, complexity metrics."""

import re
from collections import Counter
from pathlib import Path
from typing import Any

from ..util import REPO, find_nix_files, md_section, md_subsection, md_table, read_nix, rg


def section_option_inventory() -> str:
    """Section 17: Option Inventory."""
    lines = [md_section(17, "Option Inventory")]

    rc, out, _ = rg(["-cF", "mkOption"], timeout=15)
    mkopt_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkopt_total += int(l.split(":", 1)[1])

    rc, out, _ = rg(["-cF", "mkEnableOption"], timeout=15)
    mkenable_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkenable_total += int(l.split(":", 1)[1])

    rc, out, _ = rg(["-cF", "mkIf"], timeout=15)
    mkif_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkif_total += int(l.split(":", 1)[1])

    lines.append(
        md_table(
            ["Construct", "Count"],
            [
                ["mkOption", mkopt_total],
                ["mkEnableOption", mkenable_total],
                ["mkIf", mkif_total],
            ],
        )
    )

    lines.append(md_subsection("Option namespace references"))
    rc, out, _ = rg(["-o", r"options\.\w+"], timeout=15)
    if rc == 0 and out.strip():
        namespaces: Counter = Counter()
        for m in re.finditer(r"options\.(\w+)", out):
            namespaces[m.group(1)] += 1
        rows = sorted(namespaces.items(), key=lambda x: -x[1])
        lines.append(md_table(["Namespace", "References"], [[k, v] for k, v in rows]))
    return "\n".join(lines)


def section_nix_idiom() -> str:
    """Section 18: Nix Idiom Usage."""
    lines = [md_section(18, "Nix Idiom Usage")]
    idioms = [
        "lib.genAttrs",
        "lib.optional",
        "lib.optionalAttrs",
        "lib.mapAttrs",
        "lib.mkMerge",
        "lib.pipe",
        "lib.foldl'",
        "lib.filterAttrs",
        "lib.nameValuePair",
        "lib.listToAttrs",
        "lib.concatMap",
        "lib.flatten",
        "lib.zipAttrsWith",
    ]
    rc, out, _ = rg(["-o", r"lib\.\w+"], timeout=15)
    counts: Counter = Counter()
    if rc == 0 and out.strip():
        counts.update(re.findall(r"lib\.\w+", out))
    rows: list[list[Any]] = []
    for idiom in idioms:
        rows.append([idiom, counts.get(idiom, 0)])
    all_others = {k: v for k, v in counts.items() if k not in idioms}
    top_others = sorted(all_others.items(), key=lambda x: -x[1])[:5]
    for k, v in top_others:
        rows.append([k, v])
    lines.append(md_table(["Idiom", "Count"], sorted(rows, key=lambda x: -x[1])))
    return "\n".join(lines)


def section_conditional_builtins() -> str:
    """Section 19: Conditional & Builtins Usage."""
    lines = [md_section(19, "Conditional & Builtins Usage")]

    lines.append(md_subsection("Conditional logic"))
    cond_pats = ["mkIf", "mkDefault", "mkForce", "mkOption", "mkEnableOption"]
    rows: list[list[Any]] = []
    for pat in cond_pats:
        rc, out, _ = rg(["-cF", pat], timeout=15)
        total = 0
        files = 0
        if rc == 0 and out.strip():
            for l in out.strip().splitlines():
                if ":" in l:
                    total += int(l.split(":", 1)[1])
                    files += 1
        rows.append([pat, total, files])
    lines.append(md_table(["Construct", "Count", "Files"], rows))

    lines.append(md_subsection("Builtins frequency (top 15)"))
    rc, out, _ = rg(["-o", "--no-filename", r"builtins\.\w+"], timeout=15)
    if rc == 0 and out.strip():
        counts: Counter = Counter(out.strip().splitlines())
        top = counts.most_common(15)
        lines.append(md_table(["Builtin", "Count"], [list(x) for x in top]))
    return "\n".join(lines)


def _nix_depth_and_interp(text: str) -> tuple[int, int]:
    """Return (max_let_in_depth, interp_count) with string-awareness.

    Tracks `` '' `` and `` "`` string contexts and comments (`` // `` and `` /* */``)
    so that keywords and interpolation syntax inside string literals are not counted.
    """
    depth = 0
    maxdepth = 0
    interp = 0

    in_double = False
    in_indented = False
    in_block_comment = False

    lines = text.splitlines(keepends=True)
    line_starts_in_str = []

    for line in lines:
        line_starts_in_str.append(in_double or in_indented or in_block_comment)

        j = 0
        while j < len(line):
            ch = line[j]

            if in_block_comment:
                if line[j : j + 2] == "*/":
                    in_block_comment = False
                    j += 2
                else:
                    j += 1
                continue

            if in_indented:
                if line[j : j + 2] == "''":
                    if j + 2 < len(line) and line[j + 2] == "$":
                        if j + 3 < len(line) and line[j + 3] == "{":
                            j += 4  # ''${  — escaped literal, not interpolation
                            continue
                        j += 3  # ''$   — escaped literal $
                        continue
                    if j + 2 < len(line) and line[j + 2] == "'":
                        j += 3  # '''' — literal '
                        continue
                    if j + 2 < len(line) and line[j + 2] in "\n\r":
                        j += 2  # '' + newline — line continuation
                        continue
                    in_indented = False
                    j += 2
                    continue
                if line[j : j + 2] == "${":
                    interp += 1
                    paren_depth = 1
                    j += 2
                    while j < len(line) and paren_depth > 0:
                        if line[j] == "{":
                            paren_depth += 1
                        elif line[j] == "}":
                            paren_depth -= 1
                        j += 1
                    continue
                j += 1
                continue

            if in_double:
                if ch == "\\":
                    j += 2
                    continue
                if ch == '"':
                    in_double = False
                    j += 1
                    continue
                if line[j : j + 2] == "${":
                    interp += 1
                    paren_depth = 1
                    j += 2
                    while j < len(line) and paren_depth > 0:
                        if line[j] == "{":
                            paren_depth += 1
                        elif line[j] == "}":
                            paren_depth -= 1
                        j += 1
                    continue
                j += 1
                continue

            # Outside any string / comment
            if line[j : j + 2] == "//":
                break  # rest of line is comment
            if line[j : j + 2] == "/*":
                in_block_comment = True
                j += 2
                continue
            if line[j : j + 2] == "${":
                interp += 1
                paren_depth = 1
                j += 2
                while j < len(line) and paren_depth > 0:
                    if line[j] == "{":
                        paren_depth += 1
                    elif line[j] == "}":
                        paren_depth -= 1
                    j += 1
                continue
            if line[j : j + 2] == "''":
                in_indented = True
                j += 2
                continue
            if ch == '"':
                in_double = True
                j += 1
                continue
            j += 1

    for li, line in enumerate(lines):
        if not line_starts_in_str[li]:
            s = line.strip()
            if s.startswith("let ") or s == "let":
                depth += 1
                maxdepth = max(maxdepth, depth)
            elif s.startswith("in ") or s == "in":
                depth = max(0, depth - 1)

    return maxdepth, interp


def _complexity_score_raw(filepath: Path) -> tuple[int, int, int, int, int]:
    """Return (score, maxdepth, interp_count, cond_count, loc)."""
    text = read_nix(filepath)
    score = 0
    maxdepth, interp = _nix_depth_and_interp(text)
    if maxdepth >= 3:
        score += 3
    elif maxdepth >= 2:
        score += 1
    if interp > 30:
        score += 3
    elif interp > 15:
        score += 2
    elif interp > 5:
        score += 1
    cond = len(re.findall(r"mkIf|mkDefault|mkForce", text))
    if cond > 10:
        score += 3
    elif cond > 5:
        score += 2
    elif cond > 2:
        score += 1
    loc = len(text.splitlines())
    if loc > 300:
        score += 3
    elif loc > 150:
        score += 2
    elif loc > 80:
        score += 1
    return score, maxdepth, interp, cond, loc


def section_complexity_metrics() -> str:
    """Section 20: Complexity Metrics."""
    lines = [md_section(20, "Complexity Metrics")]

    rows: list[list[Any]] = []
    for f in find_nix_files():
        score, maxdepth, interp, cond, loc = _complexity_score_raw(f)
        if score == 0:
            continue
        reasons = []
        if maxdepth >= 2:
            reasons.append(f"depth={maxdepth}")
        if interp > 5:
            reasons.append(f"interp={interp}")
        if cond > 2:
            reasons.append(f"cond={cond}")
        if loc > 80:
            reasons.append(f"LOC={loc}")
        rel = f.relative_to(REPO)
        rows.append([score, f"`{rel}`", ", ".join(reasons)])
    rows.sort(reverse=True)
    lines.append(md_subsection("All files with non-trivial complexity"))
    lines.append(md_table(["Score", "File", "Contributing factors"], rows))
    return "\n".join(lines)


def _estimate_attrset_size(text: str) -> int:
    """Heuristic: count 'name = expr;' lines in top-level brace block."""
    count = 0
    in_brace = 0
    for line in text.splitlines():
        stripped = line.strip()
        if "{" in stripped:
            in_brace += stripped.count("{")
        if "}" in stripped:
            in_brace -= stripped.count("}")
        if in_brace > 0 and "=" in stripped and stripped.rstrip().endswith(";"):
            count += 1
    return count


def _estimate_list_entries(text: str) -> int:
    """Heuristic: count lines with standalone entries between [ and ]."""
    entries = 0
    in_bracket = 0
    for line in text.splitlines():
        stripped = line.strip()
        if "[" in stripped:
            in_bracket += 1
            continue
        if in_bracket > 0:
            if "]" in stripped:
                if stripped.rstrip().endswith("]") and not stripped.startswith("]"):
                    entries += 1
                in_bracket -= 1
            else:
                entries += 1
    return entries


def _longest_string(text: str) -> int:
    """Approximate longest string literal by line count (multi-line '' strings)."""
    max_lines = 0
    in_string = False
    current_lines = 0
    i = 0
    while i < len(text):
        if not in_string and text[i : i + 2] == "''":
            in_string = True
            current_lines = 1
            i += 2
        elif in_string and text[i : i + 2] == "''":
            in_string = False
            max_lines = max(max_lines, current_lines)
            i += 2
        elif in_string:
            if text[i] == "\n":
                current_lines += 1
            i += 1
        else:
            i += 1
    return max_lines


def _deepest_pipeline(text: str) -> int:
    """Max consecutive |> operators."""
    best = 0
    for line in text.splitlines():
        count = line.count("|>")
        best = max(best, count)
    return best


def section_interesting_complexity() -> str:
    """Section 21: "Interesting" Complexity Metrics."""
    lines = [md_section(21, '"Interesting" Complexity Metrics')]

    top_by_metric: dict[str, list[tuple[int, str]]] = {
        "Deepest attrset nesting": [],
        "Most rec blocks": [],
        "Most with blocks": [],
        "Deepest mkIf nesting": [],
        "Largest attrset": [],
        "Largest list": [],
        "Longest string (lines)": [],
        "Deepest function pipeline (|>)": [],
    }

    for f in find_nix_files():
        text = read_nix(f)
        rel = str(f.relative_to(REPO))

        max_brace = 0
        brace_depth = 0
        for ch in text:
            if ch == "{":
                brace_depth += 1
                max_brace = max(max_brace, brace_depth)
            elif ch == "}":
                brace_depth = max(0, brace_depth - 1)
        top_by_metric["Deepest attrset nesting"].append((max_brace, rel))

        rec_count = len(re.findall(r"\brec\b", text))
        top_by_metric["Most rec blocks"].append((rec_count, rel))

        with_count = len(re.findall(r"\bwith\b", text))
        top_by_metric["Most with blocks"].append((with_count, rel))

        max_mkif = 0
        for m in re.finditer(r"mkIf\s*\(", text):
            pos = m.end()
            paren_depth = 0
            for ch in text[pos : pos + 200]:
                if ch == "(":
                    paren_depth += 1
                elif ch == ")":
                    if paren_depth == 0:
                        break
                    paren_depth -= 1
                max_mkif = max(max_mkif, paren_depth)
        top_by_metric["Deepest mkIf nesting"].append((max_mkif, rel))

        attr_count = _estimate_attrset_size(text)
        top_by_metric["Largest attrset"].append((attr_count, rel))

        list_entries = _estimate_list_entries(text)
        top_by_metric["Largest list"].append((list_entries, rel))

        str_lines = _longest_string(text)
        top_by_metric["Longest string (lines)"].append((str_lines, rel))

        pipe_depth = _deepest_pipeline(text)
        top_by_metric["Deepest function pipeline (|>)"].append((pipe_depth, rel))

    for metric, entries in top_by_metric.items():
        lines.append(md_subsection(metric.replace("_", " ").title()))
        entries.sort(reverse=True)
        top = entries[:8]
        lines.append(
            md_table(["Value", "File"], [[str(v), f"`{f}`"] for v, f in top if v > 0])
        )
    return "\n".join(lines)


def section_error_handling() -> str:
    """Section 22: Error Handling."""
    lines = [md_section(22, "Error Handling")]
    counts: dict[str, int] = {}
    for pat, name in [
        (r"builtins\.throw|throw ", "throw"),
        (r"builtins\.abort|abort ", "abort"),
        (r"\bassert ", "assert"),
    ]:
        rc, out, _ = rg(["-c", pat], timeout=15)
        total = 0
        if rc == 0 and out.strip():
            for l in out.strip().splitlines():
                if ":" in l:
                    total += int(l.split(":", 1)[1])
        counts[name] = total
    lines.append(md_table(["Construct", "Count"], [[k, v] for k, v in counts.items()]))
    lines.append(md_subsection("Throw locations"))
    rc, out, _ = rg(["-n", r'throw "'], timeout=15)
    if rc == 0 and out.strip():
        for l in out.strip().splitlines()[:12]:
            lines.append(f"- `{l}`")
    return "\n".join(lines)
