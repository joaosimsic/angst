#!/usr/bin/env python3
"""angst flake analysis — Markdown report.

Usage:
    python scripts/analyze-flake.py [--no-eval-cost] [--no-color]

Outputs a Markdown report to stdout.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

REPO = Path.cwd()

# ── helpers ───────────────────────────────────

def has_cmd(name: str) -> bool:
    return shutil.which(name) is not None


def run(
    cmd: list[str],
    timeout: int | None = 120,
    check: bool = False,
    **kwargs,
) -> tuple[int, str, str]:
    try:
        r = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            **kwargs,
        )
        if check:
            r.check_returncode()
        return r.returncode, r.stdout, r.stderr
    except FileNotFoundError:
        return -1, "", f"command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return -1, "", f"timed out ({timeout}s)"
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout, e.stderr


def run_quiet(cmd: list[str], **kwargs) -> str:
    """Run and return stdout.strip(); empty string on failure."""
    rc, out, _ = run(cmd, **kwargs)
    return out.strip() if rc == 0 else ""


def find_nix_files(root: Path | None = None) -> list[Path]:
    root = root or REPO
    result: list[Path] = []
    for p in root.rglob("*.nix"):
        parts = p.relative_to(REPO).parts
        if ".git" in parts or "result" in parts:
            continue
        # exclude tools subflakes (vm, shell) — they are separate flakes
        if len(parts) >= 2 and parts[0] == "tools" and parts[1] in ("vm", "shell"):
            continue
        result.append(p)
    return sorted(result)


def nix_eval(
    attr: str,
    apply: str | None = None,
    json_out: bool = False,
    **kwargs,
) -> tuple[int, str, str]:
    """nix eval wrapper."""
    cmd = ["nix", "eval", f".#{attr}", "--no-warn-dirty"]
    if json_out:
        cmd.append("--json")
    if apply:
        cmd.extend(["--apply", apply])
    return run(cmd, **kwargs)


def nix_eval_attr_names(attr: str, **kwargs) -> list[str]:
    """Return list of attribute names under #.attr."""
    rc, out, err = nix_eval(attr, apply="builtins.attrNames", json_out=True, **kwargs)
    if rc != 0:
        return []
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return []


def git_log(patterns: list[str], since: str = "1 year ago") -> list[str]:
    cmd = [
        "git", "log", "--oneline", f"--since={since}",
        "--name-only", "--",
    ] + patterns
    rc, out, _ = run(cmd, timeout=30)
    if rc != 0:
        return []
    return [l for l in out.splitlines() if l and not l.startswith(("commit ", "Date:"))]


# ── markdown helpers ──────────────────────────

def md_escape(s: str | int | float) -> str:
    return str(s).replace("|", "\\|")


def md_table(headers: list[str], rows: list[list[Any]]) -> str:
    lines = ["| " + " | ".join(str(h) for h in headers) + " |"]
    lines.append("|" + "|".join("---" for _ in headers) + "|")
    for row in rows:
        lines.append("| " + " | ".join(md_escape(c) for c in row) + " |")
    return "\n".join(lines)


def md_section(n: int, title: str) -> str:
    return f"\n## {n}. {title}\n"


def md_subsection(title: str) -> str:
    return f"\n### {title}\n"


def md_code(text: str, lang: str = "") -> str:
    return f"```{lang}\n{text}\n```"


# ── file parsing ──────────────────────────────

def read_nix(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def parse_imports(text: str, base_dir: Path) -> list[Path]:
    """Extract imported .nix file paths relative to base_dir."""
    imports: list[Path] = []
    for m in re.finditer(
        r"""import\s+(?:\(?\s*)(\.\.?/[^'"\s;)]+)\.nix|import\s+(?:\(?\s*)["'](\.\.?/[^"'\s;)]+)["']""",
        text,
    ):
        raw = (m.group(1) or m.group(2)).rstrip("/")
        if raw.startswith("."):
            full = (base_dir / raw).resolve()
            # Nix adds .nix implicitly
            for candidate in [full, full.with_suffix(".nix")]:
                if candidate.exists() and candidate.suffix == ".nix":
                    imports.append(candidate)
                    break
    return imports


def parse_imports_from_tree(
    files: list[Path],
) -> tuple[dict[Path, list[Path]], dict[Path, int]]:
    """Return (fan_out: file -> imports, fan_in: file -> import_count)."""
    fan_out: dict[Path, list[Path]] = {}
    fan_in: Counter = Counter()
    for f in files:
        text = read_nix(f)
        deps = parse_imports(text, f.parent)
        fan_out[f] = deps
        for d in deps:
            fan_in[d] += 1
    return fan_out, dict(fan_in)


# ── analysis sections ─────────────────────────

def section_overview(no_eval_cost: bool = False) -> str:
    lines = [md_section(1, "Overview")]
    nix_files = find_nix_files()
    total_nix_loc = sum(len(read_nix(f).splitlines()) for f in nix_files)
    total_rust_loc = sum(len(read_nix(f).splitlines()) for f in Path("tools").rglob("*.rs")
                         if ".git" not in f.parts)
    total_sh_loc = sum(len(read_nix(f).splitlines()) for f in Path("scripts").rglob("*.sh")
                       if ".git" not in f.parts)
    total_md_loc = sum(len(read_nix(f).splitlines()) for f in Path("openwiki").rglob("*.md")
                       if ".git" not in f.parts)

    rows = [
        ["Files", f"{len(nix_files)} .nix files, {total_nix_loc} LOC"],
        ["Rust", f"{total_rust_loc} LOC (tools/vm + tools/shell)"],
        ["Scripts", f"{total_sh_loc} LOC (bash)"],
        ["Docs", f"{total_md_loc} LOC (openwiki)"],
    ]

    if not no_eval_cost:
        rc, _, err = run(["nix", "flake", "check", "--no-build"], timeout=60)
        if rc == 0:
            rows.append(["Flake check", "✓ passed"])
        else:
            short = err.strip().split("\n")[-1] if err.strip() else "failed"
            rows.append(["Flake check", f"✗ {short}"])
    else:
        rows.append(["Flake check", "skipped (--no-eval-cost)"])

    lines.append(md_table(["Metric", "Value"], rows))
    return "\n".join(lines)


def section_file_size_heatmap() -> str:
    lines = [md_section(2, "File Size Heatmap (top 30)")]
    entries: list[tuple[int, str, str]] = []
    for f in find_nix_files():
        loc = len(read_nix(f).splitlines())
        rel = f.relative_to(REPO)
        section = rel.parts[0] if len(rel.parts) > 1 else "root"
        entries.append((loc, str(rel), section))
    entries.sort(reverse=True)
    rows: list[list[Any]] = []
    for loc, rel, section in entries[:30]:
        rows.append([loc, rel, section])
    lines.append(md_table(["LOC", "File", "Section"], rows))
    return "\n".join(lines)


def section_directory_breakdown() -> str:
    lines = [md_section(3, "Directory Size Breakdown")]
    rows: list[list[Any]] = []
    for d in ("lib", "domains", "toolchains", "themes", "capabilities", "hosts", "common", "scripts"):
        path = REPO / d
        if not path.is_dir():
            continue
        nix_count = sum(1 for _ in path.rglob("*.nix") if ".git" not in _.parts)
        nix_loc = sum(len(read_nix(f).splitlines()) for f in path.rglob("*.nix")
                      if ".git" not in f.parts)
        extra = ""
        if d == "tools":
            rc = sum(1 for _ in Path("tools").rglob("*.rs"))
            rl = sum(len(read_nix(f).splitlines()) for f in Path("tools").rglob("*.rs"))
            if rc:
                extra = f" (+{rc} .rs files, {rl} LOC)"
        elif d == "scripts":
            sc = sum(1 for _ in path.rglob("*.sh"))
            sl = sum(len(read_nix(f).splitlines()) for f in path.rglob("*.sh"))
            if sc:
                extra = f" (+{sc} .sh files, {sl} LOC)"
        rows.append([f"{d}/", nix_count, nix_loc, extra])
    lines.append(md_table(["Directory", ".nix files", "LOC", "Extra"], rows))
    return "\n".join(lines)


def section_attribute_surface() -> str:
    lines = [md_section(4, "Attribute Surface")]
    pairs = [
        ("packages", "packages.x86_64-linux"),
        ("devShells", "devShells.x86_64-linux"),
        ("apps", "apps.x86_64-linux"),
        ("checks", "checks.x86_64-linux"),
        ("nixosConfig", "nixosConfigurations"),
        ("homeConfig", "homeConfigurations"),
    ]
    rows: list[list[Any]] = []
    for label, attr in pairs:
        names = nix_eval_attr_names(attr)
        rows.append([label, str(len(names)), ", ".join(names[:8]) + ("..." if len(names) > 8 else "")])
    lines.append(md_table(["Output", "Count", "Entries"], rows))
    return "\n".join(lines)


def section_config_matrix() -> str:
    lines = [md_section(5, "Configuration Matrix")]

    hosts = sorted(d.name for d in REPO.joinpath("hosts").iterdir() if d.is_dir())

    themes = sorted(
        f.stem for f in REPO.joinpath("themes").glob("*.nix")
        if f.stem not in ("default", "schema")
    )

    domains: list[str] = []
    domains_path = REPO / "domains"
    if domains_path.is_dir():
        for cat in sorted(domains_path.iterdir()):
            if cat.is_dir():
                for d in cat.iterdir():
                    if d.is_dir():
                        domains.append(f"{cat.name}/{d.name}")

    architectures = nix_eval_attr_names("packages") or ["x86_64-linux"]

    rows: list[list[Any]] = [
        ["Hosts", str(len(hosts)), ", ".join(hosts)],
        ["Themes", str(len(themes)), ", ".join(themes)],
        ["Architectures", str(len(architectures)), ", ".join(architectures)],
        ["Domains", str(len(domains)), f"{len(domains)} domains in {len(set(d.split('/')[0] for d in domains))} categories"],
    ]
    lines.append(md_table(["Dimension", "Count", "Values"], rows))

    combo_host_theme = len(hosts) * len(themes)
    lines.append(f"\n> **Possible host/theme configurations:** {len(hosts)} × {len(themes)} = {combo_host_theme}")
    return "\n".join(lines)


def section_render_coverage() -> str:
    lines = [md_section(6, "Render Coverage")]
    total = 0
    counts: Counter[str] = Counter()
    domains_path = REPO / "domains"
    if not domains_path.is_dir():
        return lines[0] + "\n(no domains/)"
    for cat in sorted(domains_path.iterdir()):
        if not cat.is_dir():
            continue
        for d in cat.iterdir():
            if not d.is_dir():
                continue
            total += 1
            if (d / "render.nix").exists():
                counts["render"] += 1
            if (d / "module.nix").exists():
                counts["home module"] += 1
            if (d / "nixos.nix").exists():
                counts["nixos module"] += 1
            if (d / "activation.nix").exists():
                counts["activation"] += 1
            if (d / "meta.nix").exists():
                checks_dir = d / "checks"
                if checks_dir.exists():
                    counts["checks"] += len(list(checks_dir.rglob("*.nix")))

    rows: list[list[Any]] = []
    labels = {
        "render": "render module",
        "home module": "home module",
        "nixos module": "nixos module",
        "activation": "activation script",
        "checks": "check files",
    }
    for key, label in labels.items():
        n = counts.get(key, 0)
        pct = f"{n * 100 // total}%" if total else "—"
        rows.append([label, str(n), pct])
    rows.append(["**total domains**", str(total), "100%"])
    lines.append(md_table(["Feature", "Count", "Coverage"], rows))
    return "\n".join(lines)


def section_dependency_fan() -> str:
    lines = [md_section(7, "Dependency Fan-in / Fan-out")]
    files = find_nix_files()
    fan_out, fan_in = parse_imports_from_tree(files)

    # fan-in: most imported
    fi_sorted = sorted(fan_in.items(), key=lambda x: -x[1])
    fi_rows: list[list[Any]] = []
    for path, count in fi_sorted[:15]:
        rel = path.relative_to(REPO)
        fi_rows.append([str(count), str(rel)])
    lines.append(md_subsection("Most imported modules (fan-in)"))
    lines.append(md_table(["Imports", "File"], fi_rows))

    # fan-out: files importing the most
    fo_sorted = sorted(fan_out.items(), key=lambda x: -len(x[1]))
    fo_rows: list[list[Any]] = []
    for path, deps in fo_sorted[:15]:
        rel = path.relative_to(REPO)
        fo_rows.append([str(len(deps)), str(rel)])
    lines.append(md_subsection("Largest dependency fan-out"))
    lines.append(md_table(["Imports", "File"], fo_rows))
    return "\n".join(lines)


def _render_tree_lines(
    node: Path,
    fan_out: dict[Path, list[Path]],
    prefix: str,
    is_last: bool,
    visited: set[Path],
) -> list[str]:
    """Recursively render an import tree branch."""
    lines: list[str] = []
    marker = "└── " if is_last else "├── "
    rel = node.relative_to(REPO)
    lines.append(f"{prefix}{marker}{rel}")

    if node in visited:
        lines.append(f"{prefix}{'    ' if is_last else '│   '}(cycle)")
        return lines
    visited.add(node)

    deps = fan_out.get(node, [])
    child_prefix = prefix + ("    " if is_last else "│   ")
    for i, dep in enumerate(deps):
        child_is_last = i == len(deps) - 1
        child_lines = _render_tree_lines(dep, fan_out, child_prefix, child_is_last, visited)
        lines.extend(child_lines)
    visited.discard(node)
    return lines


def build_import_tree(
    root: Path,
    fan_out: dict[Path, list[Path]],
) -> str:
    lines: list[str] = []
    rel = root.relative_to(REPO)
    lines.append(str(rel))
    visited: set[Path] = set()
    deps = fan_out.get(root, [])
    for i, dep in enumerate(deps):
        child_lines = _render_tree_lines(dep, fan_out, "", i == len(deps) - 1, visited)
        lines.extend(child_lines)
    return "\n".join(lines)


def build_dot_graph(
    fan_out: dict[Path, list[Path]],
    visited: set | None = None,
) -> str:
    edges: list[str] = []
    seen_edges: set[tuple[Path, Path]] = set()

    def walk(node: Path, v: set):
        if node in v:
            return
        v.add(node)
        for dep in fan_out.get(node, []):
            if (node, dep) not in seen_edges:
                seen_edges.add((node, dep))
                src = str(node.relative_to(REPO))
                dst = str(dep.relative_to(REPO))
                edges.append(f'  "{src}" -> "{dst}";')
            walk(dep, v)

    walk(REPO / "flake.nix", set())
    lines = [
        "```dot",
        "digraph {",
        "  node [shape=box, style=rounded, fontname=monospace];",
        "  rankdir=LR;",
    ]
    lines.extend(edges)
    lines.append("}")
    lines.append("```")
    return "\n".join(lines)


def section_coupling_graph(no_graph: bool = False) -> str:
    lines = [md_section(8, "Module Coupling Graph")]
    files = find_nix_files()
    fan_out, _ = parse_imports_from_tree(files)
    root = REPO / "flake.nix"
    if not root.exists():
        return lines[0] + "\n(flake.nix not found)"
    lines.append(md_subsection("Import tree (from flake.nix)"))
    lines.append(md_code(build_import_tree(root, fan_out)))
    if not no_graph:
        lines.append(md_subsection("Graphviz (DOT)"))
        lines.append(build_dot_graph(fan_out))
    return "\n".join(lines)


def max_import_depth(
    node: Path,
    fan_out: dict[Path, list[Path]],
    memo: dict[Path, int] | None = None,
    visiting: set | None = None,
) -> int:
    if memo is None:
        memo = {}
    if visiting is None:
        visiting = set()
    if node in memo:
        return memo[node]
    if node in visiting:
        return 0  # cycle guard
    visiting.add(node)
    max_d = 0
    for dep in fan_out.get(node, []):
        max_d = max(max_d, 1 + max_import_depth(dep, fan_out, memo, visiting))
    memo[node] = max_d
    visiting.discard(node)
    return max_d


def section_build_depth() -> str:
    lines = [md_section(9, "Build Graph Depth")]
    files = find_nix_files()
    fan_out, _ = parse_imports_from_tree(files)
    root = REPO / "flake.nix"
    if not root.exists():
        return lines[0] + "\n(flake.nix not found)"
    depth = max_import_depth(root, fan_out)
    lines.append(f"\nMaximum dependency depth from **flake.nix**: **{depth}**")
    # also show deepest chain
    lines.append(f"\n```\nflake.nix\n{' ↓' * depth}\n(leaf)\n```")
    return "\n".join(lines)


def section_duplication() -> str:
    lines = [md_section(10, "Duplication Hotspots")]

    patterns = {
        "userEnv parsing (parseEnv.nix)": r"parseEnv\.nix|userEnv\s*=|builtins\.pathExists.*user\.env",
        '"x86_64-linux" hardcoded': r"x86_64-linux",
        '"proj/angst" hardcoded': r"proj/angst",
        '"allowUnfree" hardcoded': r"allowUnfree",
    }

    for label, pat in patterns.items():
        lines.append(md_subsection(label))
        rc, out, _ = run(["rg", "-l", pat, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=30)
        if rc == 0 and out.strip():
            for f in out.strip().splitlines():
                lines.append(f"- `{f}`")
        else:
            lines.append("_(none found)_")

    lines.append(md_subsection("Key re-imports (dedup candidates)"))
    for pat in ("parseEnv", "domains/default", "themes/default", "shared.nix"):
        rc, out, _ = run(["rg", "-l", pat, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
        count = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
        if count > 1:
            lines.append(f"- **{pat}**: {count} files import it")
            for f in out.strip().splitlines():
                lines.append(f"  - `{f}`")
    return "\n".join(lines)


def section_hardcoded_strings() -> str:
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
        rc, out, _ = run(["rg", "-cF", s, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
        total = 0
        if rc == 0 and out.strip():
            for line in out.strip().splitlines():
                if ":" in line:
                    total += int(line.split(":", 1)[1])
        rc2, out2, _ = run(["rg", "-lF", s, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
        files = len(out2.strip().splitlines()) if rc2 == 0 and out2.strip() else 0
        rows.append([f'"{s}"', total, files, desc])
    lines.append(md_table(["String", "Occurrences", "Files", "Description"], rows))
    return "\n".join(lines)


def section_domain_inventory_condensed() -> str:
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
            for d in cat.iterdir() if d.is_dir()
            for f in d.rglob("*.nix") if ".git" not in f.parts
        )
        has_render = sum(1 for d in cat.iterdir() if d.is_dir() and (d / "render.nix").exists())
        has_module = sum(1 for d in cat.iterdir() if d.is_dir() and (d / "module.nix").exists())
        rows.append([cat.name, len(doms), ",".join(doms), has_render, has_module, cat_loc])
    if rows:
        lines.append(md_table(["Category", "Domains", "Names", "Render", "Module", "LOC"], rows))
    return "\n".join(lines)


def section_theme_inventory_condensed() -> str:
    lines = [md_section(13, "Theme Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    themes_dir = REPO / "themes"
    if not themes_dir.is_dir():
        return lines[0] + "\n(no themes/)"
    themes = sorted(
        f.stem for f in themes_dir.glob("*.nix")
        if f.stem not in ("default", "schema")
    )
    total_loc = sum(len(read_nix(f).splitlines()) for f in themes_dir.glob("*.nix")
                    if f.stem not in ("default", "schema"))
    lines.append(f"- **{len(themes)} themes**, {total_loc} total LOC\n")
    for t in themes:
        loc = len(read_nix(themes_dir / f"{t}.nix").splitlines())
        default_mark = " (default)" if t == "monochrome" else ""
        lines.append(f"  - `{t}` — {loc} LOC{default_mark}")
    return "\n".join(lines)


def section_capabilities_inventory_condensed() -> str:
    lines = [md_section(14, "Capabilities Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    cap_dir = REPO / "capabilities"
    if not cap_dir.is_dir():
        return lines[0] + "\n(no capabilities/)"
    caps = sorted(f.stem for f in cap_dir.glob("*.nix") if f.stem != "default")
    total_loc = sum(len(read_nix(f).splitlines()) for f in cap_dir.glob("*.nix")
                    if f.stem != "default")
    lines.append(f"- **{len(caps)} capabilities**, {total_loc} total LOC\n")
    for c in caps:
        loc = len(read_nix(cap_dir / f"{c}.nix").splitlines())
        lines.append(f"  - `{c}` — {loc} LOC")
    return "\n".join(lines)


def section_toolchain_inventory_condensed() -> str:
    lines = [md_section(15, "Toolchain Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    tc_dir = REPO / "toolchains"
    if not tc_dir.is_dir():
        return lines[0] + "\n(no toolchains/)"
    tcs = sorted(f.stem for f in tc_dir.glob("*.nix") if f.stem != "default")
    total_loc = sum(len(read_nix(f).splitlines()) for f in tc_dir.glob("*.nix")
                    if f.stem != "default")
    lines.append(f"- **{len(tcs)} toolchains**, {total_loc} total LOC\n")
    for t in tcs:
        loc = len(read_nix(tc_dir / f"{t}.nix").splitlines())
        lines.append(f"  - `{t}` — {loc} LOC")
    return "\n".join(lines)


def section_host_inventory() -> str:
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


def section_option_inventory() -> str:
    lines = [md_section(17, "Option Inventory")]

    rc, out, _ = run(["rg", "-cF", "mkOption", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
    mkopt_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkopt_total += int(l.split(":", 1)[1])

    rc, out, _ = run(["rg", "-cF", "mkEnableOption", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
    mkenable_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkenable_total += int(l.split(":", 1)[1])

    rc, out, _ = run(["rg", "-cF", "mkIf", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
    mkif_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkif_total += int(l.split(":", 1)[1])

    lines.append(md_table(
        ["Construct", "Count"],
        [
            ["mkOption", mkopt_total],
            ["mkEnableOption", mkenable_total],
            ["mkIf", mkif_total],
        ],
    ))

    # Option namespace detection: look for options.<name> patterns in module files
    lines.append(md_subsection("Option namespace references"))
    rc, out, _ = run(
        ["rg", "-o", r"options\.\w+", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"],
        timeout=15,
    )
    if rc == 0 and out.strip():
        namespaces: Counter = Counter()
        for m in re.finditer(r"options\.(\w+)", out):
            namespaces[m.group(1)] += 1
        rows = sorted(namespaces.items(), key=lambda x: -x[1])
        lines.append(md_table(["Namespace", "References"], [[k, v] for k, v in rows]))
    return "\n".join(lines)


def section_nix_idiom() -> str:
    lines = [md_section(18, "Nix Idiom Usage")]
    idioms = [
        "lib.genAttrs", "lib.optional", "lib.optionalAttrs",
        "lib.mapAttrs", "lib.mkMerge", "lib.pipe", "lib.foldl'",
        "lib.filterAttrs", "lib.nameValuePair", "lib.listToAttrs",
        "lib.concatMap", "lib.flatten", "lib.zipAttrsWith",
    ]
    rc, out, _ = run(
        ["rg", "-o", r"lib\.\w+", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"],
        timeout=15,
    )
    counts: Counter = Counter()
    if rc == 0 and out.strip():
        counts.update(re.findall(r"lib\.\w+", out))
    rows: list[list[Any]] = []
    for idiom in idioms:
        rows.append([idiom, counts.get(idiom, 0)])
    # also show top 5 others
    all_others = {k: v for k, v in counts.items() if k not in idioms}
    top_others = sorted(all_others.items(), key=lambda x: -x[1])[:5]
    for k, v in top_others:
        rows.append([k, v])
    lines.append(md_table(["Idiom", "Count"], sorted(rows, key=lambda x: -x[1])))
    return "\n".join(lines)


def section_conditional_builtins() -> str:
    lines = [md_section(19, "Conditional & Builtins Usage")]

    lines.append(md_subsection("Conditional logic"))
    cond_pats = ["mkIf", "mkDefault", "mkForce", "mkOption", "mkEnableOption"]
    rows: list[list[Any]] = []
    for pat in cond_pats:
        rc, out, _ = run(["rg", "-cF", pat, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
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
    rc, out, _ = run(
        ["rg", "-o", "--no-filename", r"builtins\.\w+", "--type", "nix",
         "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"],
        timeout=15,
    )
    if rc == 0 and out.strip():
        counts: Counter = Counter(out.strip().splitlines())
        top = counts.most_common(15)
        lines.append(md_table(["Builtin", "Count"], top))
    return "\n".join(lines)


def section_complexity_metrics() -> str:
    lines = [md_section(20, "Complexity Metrics")]

    lines.append(md_subsection("Deep let-in nesting (depth >= 3)"))
    found_any = False
    for f in find_nix_files():
        depth = 0
        maxdepth = 0
        for line in read_nix(f).splitlines():
            stripped = line.strip()
            if stripped.startswith("let ") or stripped == "let":
                depth += 1
                maxdepth = max(maxdepth, depth)
            elif stripped.startswith("in ") or stripped == "in":
                depth = max(0, depth - 1)
        if maxdepth >= 3:
            lines.append(f"- depth {maxdepth}: `{f.relative_to(REPO)}`")
            found_any = True
    if not found_any:
        lines.append("_(none with depth >= 3)_")

    lines.append(md_subsection("String interpolation hotspots"))
    rc, out, _ = run(
        ["rg", "-c", r"\$\{", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"],
        timeout=15,
    )
    if rc == 0 and out.strip():
        entries: list[tuple[int, str]] = []
        for l in out.strip().splitlines():
            if ":" in l:
                fname, count = l.rsplit(":", 1)
                try:
                    entries.append((int(count), fname))
                except ValueError:
                    pass
        entries.sort(reverse=True)
        for count, fname in entries[:10]:
            lines.append(f"- {count:4d}  `{fname}`")

    lines.append(md_subsection("Large let blocks (> 50 lines) in render.nix"))
    for f in find_nix_files():
        if f.name != "render.nix":
            continue
        lines_in = 0
        in_let = False
        let_start = 0
        for i, line in enumerate(read_nix(f).splitlines(), 1):
            stripped = line.strip()
            if stripped == "let":
                in_let = True
                let_start = i
                lines_in = 0
            elif stripped == "in" and in_let:
                if lines_in > 50:
                    lines.append(f"- {lines_in} lines  `{f.relative_to(REPO)}`:{let_start}")
                in_let = False
            elif in_let:
                lines_in += 1
    return "\n".join(lines)


def section_interesting_complexity() -> str:
    lines = [md_section(21, '"Interesting" Complexity Metrics')]

    top_by_metric: dict[str, list[tuple[int, str]]] = {
        "Deepest attrset nesting": [],
        "Most rec blocks": [],
        "Most with blocks": [],
        "Deepest mkIf nesting": [],
    }

    for f in find_nix_files():
        text = read_nix(f)
        rel = str(f.relative_to(REPO))

        # Count brace depth (attrset proxy)
        max_brace = 0
        brace_depth = 0
        for ch in text:
            if ch == "{":
                brace_depth += 1
                max_brace = max(max_brace, brace_depth)
            elif ch == "}":
                brace_depth = max(0, brace_depth - 1)
        top_by_metric["Deepest attrset nesting"].append((max_brace, rel))

        # rec block count
        rec_count = len(re.findall(r"\brec\b", text))
        top_by_metric["Most rec blocks"].append((rec_count, rel))

        # with block count
        with_count = len(re.findall(r"\bwith\b", text))
        top_by_metric["Most with blocks"].append((with_count, rel))

        # nested mkIf depth (max paren depth after mkIf)
        max_mkif = 0
        for m in re.finditer(r"mkIf\s*\(", text):
            pos = m.end()
            paren_depth = 0
            for ch in text[pos:pos + 200]:
                if ch == "(":
                    paren_depth += 1
                elif ch == ")":
                    if paren_depth == 0:
                        break
                    paren_depth -= 1
                max_mkif = max(max_mkif, paren_depth)
        top_by_metric["Deepest mkIf nesting"].append((max_mkif, rel))

    for metric, entries in top_by_metric.items():
        lines.append(md_subsection(metric.replace("_", " ").title()))
        entries.sort(reverse=True)
        top = entries[:8]
        lines.append(md_table(["Value", "File"], [[str(v), f"`{f}`"] for v, f in top if v > 0]))
    return "\n".join(lines)


def section_error_handling() -> str:
    lines = [md_section(22, "Error Handling")]
    counts: dict[str, int] = {}
    for pat, name in [(r"builtins\.throw|throw ", "throw"), (r"builtins\.abort|abort ", "abort"), (r"\bassert ", "assert")]:
        rc, out, _ = run(["rg", "-c", pat, "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
        total = 0
        if rc == 0 and out.strip():
            for l in out.strip().splitlines():
                if ":" in l:
                    total += int(l.split(":", 1)[1])
        counts[name] = total
    lines.append(md_table(["Construct", "Count"], [[k, v] for k, v in counts.items()]))
    lines.append(md_subsection("Throw locations"))
    rc, out, _ = run(["rg", "-n", r'throw "', "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=15)
    if rc == 0 and out.strip():
        for l in out.strip().splitlines()[:12]:
            lines.append(f"- `{l}`")
    return "\n".join(lines)


def section_dead_code() -> str:
    lines = [md_section(23, "Dead Code")]
    if not has_cmd("deadnix"):
        lines.append("> `deadnix` not found. Install with `nix shell nixpkgs#deadnix`.\n")
        return "\n".join(lines)
    rc, out, _ = run(["deadnix", ".", "--quiet", "--no-lambda-pattern-names"], timeout=30)
    if rc > 1:
        lines.append("_(deadnix encountered an error)_")
    elif out.strip():
        lines.append(md_code(out.strip()))
    else:
        lines.append("✓ No dead code detected.")
    return "\n".join(lines)


def section_anti_patterns() -> str:
    lines = [md_section(24, "Anti-Patterns (statix)")]
    if not has_cmd("statix"):
        lines.append("> `statix` not found. Install with `nix shell nixpkgs#statix`.\n")
        return "\n".join(lines)
    rc, out, _ = run(["statix", "check", "."], timeout=30)
    if rc > 1:
        lines.append("_(statix encountered an error)_")
    elif out.strip():
        lines.append(md_code(out.strip()))
    else:
        lines.append("✓ No anti-patterns detected.")
    return "\n".join(lines)


def section_eval_cost(no_eval_cost: bool) -> str:
    lines = [md_section(25, "Evaluation Cost")]
    if no_eval_cost:
        lines.append("> Skipped (`--no-eval-cost`)\n")
        return "\n".join(lines)

    trials: list[tuple[str, list[str], int]] = [
        ("nix flake check", ["nix", "flake", "check", "--no-build"], 120),
        ("nix flake show", ["nix", "flake", "show"], 120),
    ]
    # nix eval for each output type
    for label, attr in [
        ("eval: packages.x86_64-linux", "packages.x86_64-linux"),
        ("eval: apps.x86_64-linux", "apps.x86_64-linux"),
        ("eval: checks.x86_64-linux", "checks.x86_64-linux"),
    ]:
        trials.append((label, ["nix", "eval", f".#{attr}", "--apply", "builtins.attrNames"], 60))

    rows: list[list[Any]] = []
    for label, cmd, timeout in trials:
        start = time.perf_counter()
        rc, out, err = run(cmd, timeout=timeout)
        elapsed = time.perf_counter() - start
        status = "✓" if rc == 0 else "✗"
        if "timed out" in err:
            status = "⚠"
            elapsed = float(timeout)
        rows.append([label, status, f"{elapsed:.2f}s"])
    lines.append(md_table(["Command", "Result", "Time"], rows))
    return "\n".join(lines)


def section_tech_debt() -> str:
    lines = [md_section(26, "Technical Debt Score")]

    checks: list[tuple[str, str, bool]] = []

    # Architecture
    files = find_nix_files()
    fan_out, fan_in = parse_imports_from_tree(files)
    # check for cycles
    has_cycle = False
    visited: set = set()
    stack: set = set()

    def has_cycle_dfs(node: Path) -> bool:
        if node in stack:
            return True
        if node in visited:
            return False
        stack.add(node)
        for dep in fan_out.get(node, []):
            if has_cycle_dfs(dep):
                return True
        stack.discard(node)
        visited.add(node)
        return False

    for f in files:
        if has_cycle_dfs(f):
            has_cycle = True
            break

    checks.append(("Architecture", "No cyclic imports", not has_cycle))

    # parseEnv duplication
    rc, out, _ = run(["rg", "-l", "parseEnv", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=10)
    parseenv_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(("Architecture", f"No parseEnv duplication ({parseenv_files} files)", parseenv_files <= 4))

    # x86_64 hardcoded
    rc, out, _ = run(["rg", "-l", "x86_64-linux", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=10)
    x86_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(("Portability", f"Minimal x86_64 hardcoding ({x86_files} files)", x86_files <= 5))

    # repoPath hardcoded
    rc, out, _ = run(["rg", "-l", "proj/angst", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=10)
    repo_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(("Portability", f"Minimal proj/angst hardcoding ({repo_files} files)", repo_files <= 3))

    # absolute store paths
    rc, out, _ = run(["rg", "-l", "/nix/store", "--type", "nix", "-g", "!.git", "-g", "!result", "-g", "!tools/vm/**", "-g", "!tools/shell/**"], timeout=10)
    store_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(("Portability", f"No absolute /nix/store paths ({store_files} files)", store_files <= 1))

    # domain registration
    domains_dir = REPO / "domains"
    all_domains_have_meta = True
    if domains_dir.is_dir():
        for cat in domains_dir.iterdir():
            if not cat.is_dir():
                continue
            for d in cat.iterdir():
                if d.is_dir() and not (d / "meta.nix").exists():
                    all_domains_have_meta = False
                    break
    checks.append(("Configuration", "All domains have meta.nix", all_domains_have_meta))

    # statix
    statix_ok = True
    if has_cmd("statix"):
        rc, _, _ = run(["statix", "check", "."], timeout=30)
        statix_ok = rc == 0
    checks.append(("Evaluation", "Statix clean", statix_ok))

    # deadnix
    deadnix_ok = True
    if has_cmd("deadnix"):
        rc, _, _ = run(["deadnix", ".", "--quiet", "--no-lambda-pattern-names"], timeout=30)
        deadnix_ok = rc == 0
    checks.append(("Evaluation", "No dead code (deadnix clean)", deadnix_ok))

    # Group by category
    categories: dict[str, list[tuple[str, str, bool]]] = {}
    for cat, desc, ok in checks:
        categories.setdefault(cat, []).append((desc, ok))

    for cat in ["Architecture", "Portability", "Configuration", "Evaluation"]:
        items = categories.get(cat, [])
        if not items:
            continue
        lines.append(f"\n### {cat}\n")
        for desc, ok in items:
            prefix = "✓" if ok else "⚠"
            lines.append(f"- {prefix} {desc}")

    return "\n".join(lines)


def section_hotspot_table() -> str:
    lines = [md_section(27, "Hotspot Table")]
    lines.append("> Cross-references file size, git churn, dependency counts, and complexity into a single view.\n")
    lines.append("> **Columns**: LOC (size), Churn (commits/year), Imports (fan-out), Dependents (fan-in),")
    lines.append("> Complexity (derived from nesting depth, string interpolation, conditional count).\n")

    files = find_nix_files()
    fan_out, fan_in = parse_imports_from_tree(files)

    # churn
    rc, out, _ = run(
        ["git", "log", "--oneline", "--since=1 year ago", "--name-only", "--", "*.nix", "*.sh", "*.rs"],
        timeout=30,
    )
    churn: Counter = Counter()
    if rc == 0:
        for line in out.splitlines():
            line = line.strip()
            if not line or line[0].isdigit() or line.startswith("commit "):
                continue
            churn[line] += 1

    # complexity score
    def complexity_score(filepath: Path) -> str:
        text = read_nix(filepath)
        score = 0
        # deep let nesting
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
        elif maxdepth >= 2:
            score += 1
        # string interpolation
        interp = len(re.findall(r"\$\{", text))
        if interp > 30:
            score += 3
        elif interp > 15:
            score += 2
        elif interp > 5:
            score += 1
        # conditionals
        cond = len(re.findall(r"mkIf|mkDefault|mkForce", text))
        if cond > 10:
            score += 3
        elif cond > 5:
            score += 2
        elif cond > 2:
            score += 1
        # LOC factor
        loc = len(text.splitlines())
        if loc > 300:
            score += 3
        elif loc > 150:
            score += 2
        elif loc > 80:
            score += 1

        if score >= 7:
            return "Very High"
        elif score >= 5:
            return "High"
        elif score >= 3:
            return "Medium"
        elif score >= 1:
            return "Low"
        return "Minimal"

    rows: list[list[Any]] = []
    for f in files:
        rel = str(f.relative_to(REPO))
        loc = len(read_nix(f).splitlines())
        ch = churn.get(rel, 0)
        im = len(fan_out.get(f, []))
        de = fan_in.get(f, 0)
        cx = complexity_score(f)
        rows.append([f"`{rel}`", loc, ch, im, de, cx])

    # sort by LOC then churn
    rows.sort(key=lambda r: (-r[1], -r[2]))
    header = ["File", "LOC", "Churn", "Imports", "Dependents", "Complexity"]
    lines.append(md_table(header, rows[:25]))
    return "\n".join(lines)


# ── main ──────────────────────────────────────

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="angst flake analysis — Markdown report")
    p.add_argument("--no-eval-cost", action="store_true", help="Skip evaluation timing (opt-out)")
    p.add_argument("--no-graph", action="store_true", help="Skip DOT graph generation")
    return p.parse_args(argv)


def main() -> None:
    args = parse_args()
    no_eval_cost = args.no_eval_cost
    no_graph = args.no_graph

    def slug(s: str) -> str:
        s = s.lower()
        s = re.sub(r'[^a-z0-9]+', '-', s)
        return s.strip('-')

    section_fns: list[tuple[str, str]] = [
        ("1. Overview", section_overview(no_eval_cost)),
        ("2. File Size Heatmap (top 30)", section_file_size_heatmap()),
        ("3. Directory Size Breakdown", section_directory_breakdown()),
        ("4. Attribute Surface", section_attribute_surface()),
        ("5. Configuration Matrix", section_config_matrix()),
        ("6. Render Coverage", section_render_coverage()),
        ("7. Dependency Fan-in / Fan-out", section_dependency_fan()),
        ("8. Module Coupling Graph", section_coupling_graph(no_graph=no_graph)),
        ("9. Build Graph Depth", section_build_depth()),
        ("10. Duplication Hotspots", section_duplication()),
        ("11. Hardcoded Strings Inventory", section_hardcoded_strings()),
        ("12. Domain Inventory", section_domain_inventory_condensed()),
        ("13. Theme Inventory", section_theme_inventory_condensed()),
        ("14. Capabilities Inventory", section_capabilities_inventory_condensed()),
        ("15. Toolchain Inventory", section_toolchain_inventory_condensed()),
        ("16. Host Inventory", section_host_inventory()),
        ("17. Option Inventory", section_option_inventory()),
        ("18. Nix Idiom Usage", section_nix_idiom()),
        ("19. Conditional & Builtins Usage", section_conditional_builtins()),
        ("20. Complexity Metrics", section_complexity_metrics()),
        ('21. "Interesting" Complexity Metrics', section_interesting_complexity()),
        ("22. Error Handling", section_error_handling()),
        ("23. Dead Code", section_dead_code()),
        ("24. Anti-Patterns (statix)", section_anti_patterns()),
        ("25. Evaluation Cost", section_eval_cost(no_eval_cost)),
        ("26. Technical Debt Score", section_tech_debt()),
        ("27. Hotspot Table", section_hotspot_table()),
    ]

    # Document header
    print(f"# angst flake analysis\n")
    print(f"*Generated: {datetime.now():%Y-%m-%d %H:%M}*\n")

    # Table of contents
    print("## Table of Contents\n")
    for heading, _ in section_fns:
        num_dot = heading.index(".")
        num = heading[:num_dot]
        rest = heading[num_dot + 1:].strip()
        print(f"- [{heading}](#{slug(rest)})")
    print()

    for heading, result in section_fns:
        if result:
            print(result)

    print()
    print("---")
    print(f"\n*Analysis complete.*")


if __name__ == "__main__":
    main()
