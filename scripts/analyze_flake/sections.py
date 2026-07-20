"""Analysis sections for angst flake report."""

import re
import time
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from .util import (
    REPO,
    has_cmd,
    run,
    find_nix_files,
    nix_eval_attr_names,
    md_table,
    md_section,
    md_subsection,
    md_code,
    read_nix,
    parse_imports_from_tree,
)


def section_overview(no_eval_cost: bool = False) -> str:
    """Section 1: Overview."""
    lines = [md_section(1, "Overview")]
    nix_files = find_nix_files()
    total_nix_loc = sum(len(read_nix(f).splitlines()) for f in nix_files)
    total_rust_loc = sum(
        len(read_nix(f).splitlines())
        for f in Path("tools").rglob("*.rs")
        if ".git" not in f.parts and "target" not in f.parts
    )
    total_sh_loc = sum(
        len(read_nix(f).splitlines())
        for f in Path("scripts").rglob("*.sh")
        if ".git" not in f.parts
    )
    total_md_loc = sum(
        len(read_nix(f).splitlines())
        for f in Path("openwiki").rglob("*.md")
        if ".git" not in f.parts
    )

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
    """Section 2: File Size Heatmap."""
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
    """Section 3: Directory Size Breakdown."""
    lines = [md_section(3, "Directory Size Breakdown")]
    rows: list[list[Any]] = []
    for d in (
        "lib",
        "domains",
        "toolchains",
        "themes",
        "capabilities",
        "hosts",
        "common",
        "scripts",
    ):
        path = REPO / d
        if not path.is_dir():
            continue
        nix_count = sum(1 for _ in path.rglob("*.nix") if ".git" not in _.parts)
        nix_loc = sum(
            len(read_nix(f).splitlines())
            for f in path.rglob("*.nix")
            if ".git" not in f.parts
        )
        extra = ""
        if d == "tools":
            rc = sum(1 for _ in Path("tools").rglob("*.rs") if "target" not in _.parts)
            rl = sum(len(read_nix(f).splitlines()) for f in Path("tools").rglob("*.rs") if "target" not in f.parts)
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
    """Section 4: Attribute Surface."""
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
        rows.append(
            [
                label,
                str(len(names)),
                ", ".join(names[:8]) + ("..." if len(names) > 8 else ""),
            ]
        )
    lines.append(md_table(["Output", "Count", "Entries"], rows))
    return "\n".join(lines)


def section_config_matrix() -> str:
    """Section 5: Configuration Matrix."""
    lines = [md_section(5, "Configuration Matrix")]

    hosts_dir = REPO / "hosts"
    hosts = sorted(d.name for d in hosts_dir.iterdir() if d.is_dir()) if hosts_dir.is_dir() else []

    themes = sorted(
        f.stem
        for f in REPO.joinpath("themes").glob("*.nix")
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
        [
            "Domains",
            str(len(domains)),
            f"{len(domains)} domains in {len(set(d.split('/')[0] for d in domains))} categories",
        ],
    ]
    lines.append(md_table(["Dimension", "Count", "Values"], rows))

    combo_host_theme = len(hosts) * len(themes)
    lines.append(
        f"\n> **Possible host/theme configurations:** {len(hosts)} × {len(themes)}"
        f" = {combo_host_theme}"
    )
    return "\n".join(lines)


def section_render_coverage() -> str:
    """Section 6: Domain Feature Coverage."""
    lines = [md_section(6, "Domain Feature Coverage")]
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
            if (d / "nixos.nix").exists():
                counts["nixos"] += 1
            if (d / "meta.nix").exists():
                checks_dir = d / "checks"
                if checks_dir.exists():
                    counts["checks"] += len(list(checks_dir.rglob("*.nix")))

    rows: list[list[Any]] = []
    labels = {
        "render": "render.nix",
        "nixos": "nixos.nix",
        "checks": "domain checks",
    }
    for key, label in labels.items():
        n = counts.get(key, 0)
        pct = f"{n * 100 // total}%" if total else "—"
        rows.append([label, str(n), pct])
    rows.append(["**total domains**", str(total), "100%"])
    lines.append(md_table(["Feature", "Count", "Coverage"], rows))
    return "\n".join(lines)


def transitive_dependents(
    fan_out: dict[Path, list[Path]],
) -> dict[Path, int]:
    """For each file, count how many other files depend on it transitively."""
    reverse: dict[Path, set[Path]] = defaultdict(set)
    all_nodes = set(fan_out)
    for src, deps in fan_out.items():
        for d in deps:
            reverse[d].add(src)
            all_nodes.add(d)

    memo: dict[Path, set[Path]] = {}

    def closure(node: Path, visiting: set) -> set[Path]:
        """DFS to compute transitive dependents for a node."""
        if node in memo:
            return memo[node]
        if node in visiting:
            return set()
        visiting.add(node)
        result: set[Path] = set()
        for dep in reverse.get(node, set()):
            result.add(dep)
            result |= closure(dep, visiting)
        memo[node] = result
        visiting.discard(node)
        return result

    result: dict[Path, int] = {}
    for node in all_nodes:
        result[node] = len(closure(node, set()))
    return result


def section_dependency_fan() -> str:
    """Section 7: Dependency Fan-in / Fan-out."""
    lines = [md_section(7, "Dependency Fan-in / Fan-out")]
    files = find_nix_files()
    fan_out, fan_in = parse_imports_from_tree(files)

    trans = transitive_dependents(fan_out)

    fi_sorted = sorted(fan_in.items(), key=lambda x: -x[1])
    fi_rows: list[list[Any]] = []
    for path, count in fi_sorted[:15]:
        rel = path.relative_to(REPO)
        tc = trans.get(path, 0)
        fi_rows.append([str(count), str(tc), str(rel)])
    lines.append(md_subsection("Most imported modules (fan-in)"))
    lines.append(md_table(["Direct", "Transitive", "File"], fi_rows))

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
        child_lines = _render_tree_lines(
            dep, fan_out, child_prefix, child_is_last, visited
        )
        lines.extend(child_lines)
    visited.discard(node)
    return lines


def build_import_tree(
    root: Path,
    fan_out: dict[Path, list[Path]],
) -> str:
    """Render an ASCII import tree for a given root file."""
    lines: list[str] = []
    rel = root.relative_to(REPO)
    lines.append(str(rel))
    visited: set[Path] = set()
    deps = fan_out.get(root, [])
    for i, dep in enumerate(deps):
        child_lines = _render_tree_lines(dep, fan_out, "", i == len(deps) - 1, visited)
        lines.extend(child_lines)
    return "\n".join(lines)


def build_mermaid_graph(fan_out: dict[Path, list[Path]]) -> str:
    """Build a Mermaid flowchart of the module dependency graph."""
    edges: list[str] = []
    seen_edges: set[tuple[Path, Path]] = set()
    node_ids: dict[Path, str] = {}
    next_id = 0

    def nid(path: Path) -> str:
        """Return a short unique node ID for a path."""
        nonlocal next_id
        if path not in node_ids:
            node_ids[path] = f"n{next_id}"
            next_id += 1
        return node_ids[path]

    def walk(node: Path, v: set):
        """Recursively walk the import graph to collect edges."""
        if node in v:
            return
        v.add(node)
        for dep in fan_out.get(node, []):
            if (node, dep) not in seen_edges:
                seen_edges.add((node, dep))
                src_label = str(node.relative_to(REPO))
                dst_label = str(dep.relative_to(REPO))
                edges.append(
                    f'    {nid(node)}["{src_label}"] --> {nid(dep)}["{dst_label}"]'
                )
            walk(dep, v)

    walk(REPO / "flake.nix", set())

    lines = ["```mermaid", "flowchart LR"]
    lines.extend(edges)
    lines.append("```")
    return "\n".join(lines)


LAYER_ORDER = [
    "flake.nix",
    "lib",
    "common",
    "capabilities",
    "domains",
    "themes",
    "toolchains",
    "hosts",
    "scripts",
]


def _file_layer(path: Path) -> int:
    """Return numeric layer for a file. Lower = more foundational."""
    rel = path.relative_to(REPO)
    if str(rel) == "flake.nix":
        return 0
    if rel.parts and rel.parts[0] in LAYER_ORDER:
        return LAYER_ORDER.index(rel.parts[0])
    return 5


def _check_layer_violations(
    fan_out: dict[Path, list[Path]],
) -> list[tuple[Path, Path]]:
    """Return list of (importer, imported) violations where a foundational
    layer imports from a more specific layer. Entry point (flake.nix) is exempt."""
    violations: list[tuple[Path, Path]] = []
    for src, deps in fan_out.items():
        src_rel = str(src.relative_to(REPO))
        if src_rel == "flake.nix":
            continue
        src_layer = _file_layer(src)
        for dep in deps:
            dep_rel = str(dep.relative_to(REPO))
            if dep_rel == "flake.nix":
                continue
            dep_layer = _file_layer(dep)
            if src_layer < dep_layer:
                violations.append((src, dep))
    return violations


def section_coupling_graph(no_graph: bool = False) -> str:
    """Section 8: Module Coupling Graph."""
    lines = [md_section(8, "Module Coupling Graph")]
    files = find_nix_files()
    fan_out, _ = parse_imports_from_tree(files)
    root = REPO / "flake.nix"
    if not root.exists():
        return lines[0] + "\n(flake.nix not found)"

    lines.append(md_subsection("Import tree (from flake.nix)"))
    lines.append(md_code(build_import_tree(root, fan_out)))

    lines.append(md_subsection("Architectural layer validation"))
    lines.append("\nAllowed direction (foundational → specific):\n")
    lines.append("```\n" + "\n ↓\n".join(LAYER_ORDER) + "\n```\n")
    violations = _check_layer_violations(fan_out)
    if violations:
        lines.append(f"\n**{len(violations)} violations detected:**\n")
        for src, dep in violations:
            s_rel = src.relative_to(REPO)
            d_rel = dep.relative_to(REPO)
            lines.append(f"- `{s_rel}` → `{d_rel}`")
    else:
        lines.append("\n**No layer violations.**\n")

    if not no_graph:
        lines.append(md_subsection("Module Dependency Graph (Mermaid)"))
        lines.append(build_mermaid_graph(fan_out))
    return "\n".join(lines)


def deepest_import_path(
    node: Path,
    fan_out: dict[Path, list[Path]],
    memo: dict[Path, tuple[int, list[Path]]] | None = None,
    visiting: set | None = None,
) -> tuple[int, list[Path]]:
    """Return (depth, [path]) for the longest import chain from node."""
    if memo is None:
        memo = {}
    if visiting is None:
        visiting = set()
    if node in memo:
        return memo[node]
    if node in visiting:
        return 0, []
    visiting.add(node)
    best_depth = 0
    best_path: list[Path] = []
    for dep in fan_out.get(node, []):
        d, p = deepest_import_path(dep, fan_out, memo, visiting)
        if d + 1 > best_depth:
            best_depth = d + 1
            best_path = [dep] + p
    memo[node] = (best_depth, best_path)
    visiting.discard(node)
    return best_depth, best_path


def section_build_depth() -> str:
    """Section 9: Build Graph Depth."""
    lines = [md_section(9, "Build Graph Depth")]
    files = find_nix_files()
    fan_out, _ = parse_imports_from_tree(files)
    root = REPO / "flake.nix"
    if not root.exists():
        return lines[0] + "\n(flake.nix not found)"
    depth, path = deepest_import_path(root, fan_out)
    lines.append(f"\nMaximum dependency depth from **flake.nix**: **{depth}**\n")
    lines.append("Longest import chain:\n")
    lines.append("```\nflake.nix")
    for i, p in enumerate(path):
        rel = p.relative_to(REPO)
        indent = "    " * i + " └─ "
        lines.append(f"{indent}{rel}")
    lines.append("```")
    return "\n".join(lines)


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
        rc, out, _ = run(
            [
                "rg",
                "-l",
                pat,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=30,
        )
        if rc == 0 and out.strip():
            for f in out.strip().splitlines():
                lines.append(f"- `{f}`")
        else:
            lines.append("_(none found)_")

    lines.append(md_subsection("Key re-imports (dedup candidates)"))
    for pat in ("parseEnv", "domains/default", "themes/default", "shared.nix"):
        rc, out, _ = run(
            [
                "rg",
                "-l",
                pat,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=15,
        )
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
        rc, out, _ = run(
            [
                "rg",
                "-cF",
                s,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=15,
        )
        total = 0
        if rc == 0 and out.strip():
            for line in out.strip().splitlines():
                if ":" in line:
                    total += int(line.split(":", 1)[1])
        rc2, out2, _ = run(
            [
                "rg",
                "-lF",
                s,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=15,
        )
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
    """Section 14: Capabilities Inventory."""
    lines = [md_section(14, "Capabilities Inventory")]
    lines.append("> **See `nix flake show` for the full list.**\n")
    cap_dir = REPO / "capabilities"
    if not cap_dir.is_dir():
        return lines[0] + "\n(no capabilities/)"
    caps = sorted(f.stem for f in cap_dir.glob("*.nix") if f.stem != "default")
    total_loc = sum(
        len(read_nix(f).splitlines())
        for f in cap_dir.glob("*.nix")
        if f.stem != "default"
    )
    lines.append(f"- **{len(caps)} capabilities**, {total_loc} total LOC\n")
    for c in caps:
        loc = len(read_nix(cap_dir / f"{c}.nix").splitlines())
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


def section_option_inventory() -> str:
    """Section 17: Option Inventory."""
    lines = [md_section(17, "Option Inventory")]

    rc, out, _ = run(
        [
            "rg",
            "-cF",
            "mkOption",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
    mkopt_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkopt_total += int(l.split(":", 1)[1])

    rc, out, _ = run(
        [
            "rg",
            "-cF",
            "mkEnableOption",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
    mkenable_total = 0
    if rc == 0 and out.strip():
        for l in out.strip().splitlines():
            if ":" in l:
                mkenable_total += int(l.split(":", 1)[1])

    rc, out, _ = run(
        [
            "rg",
            "-cF",
            "mkIf",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
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
    rc, out, _ = run(
        [
            "rg",
            "-o",
            r"options\.\w+",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
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
    rc, out, _ = run(
        [
            "rg",
            "-o",
            r"lib\.\w+",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
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
        rc, out, _ = run(
            [
                "rg",
                "-cF",
                pat,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=15,
        )
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
        [
            "rg",
            "-o",
            "--no-filename",
            r"builtins\.\w+",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
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
        rc, out, _ = run(
            [
                "rg",
                "-c",
                pat,
                "--type",
                "nix",
                "-g",
                "!.git",
                "-g",
                "!result",
                "-g",
                "!tools/vm/**",
                "-g",
                "!tools/shell/**",
            ],
            timeout=15,
        )
        total = 0
        if rc == 0 and out.strip():
            for l in out.strip().splitlines():
                if ":" in l:
                    total += int(l.split(":", 1)[1])
        counts[name] = total
    lines.append(md_table(["Construct", "Count"], [[k, v] for k, v in counts.items()]))
    lines.append(md_subsection("Throw locations"))
    rc, out, _ = run(
        [
            "rg",
            "-n",
            r'throw "',
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=15,
    )
    if rc == 0 and out.strip():
        for l in out.strip().splitlines()[:12]:
            lines.append(f"- `{l}`")
    return "\n".join(lines)


def section_dead_code() -> str:
    """Section 23: Dead Code."""
    lines = [md_section(23, "Dead Code")]
    if not has_cmd("deadnix"):
        lines.append(
            "> `deadnix` not found. Install with `nix shell nixpkgs#deadnix`.\n"
        )
        return "\n".join(lines)
    rc, out, _ = run(
        ["deadnix", ".", "--quiet", "--no-lambda-pattern-names"], timeout=30
    )
    if rc > 1:
        lines.append("_(deadnix encountered an error)_")
    elif out.strip():
        lines.append(md_code(out.strip()))
    else:
        lines.append("✓ No dead code detected.")
    return "\n".join(lines)


def section_anti_patterns() -> str:
    """Section 24: Anti-Patterns."""
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
    """Section 25: Evaluation Cost."""
    lines = [md_section(25, "Evaluation Cost")]
    if no_eval_cost:
        lines.append("> Skipped (`--no-eval-cost`)\n")
        return "\n".join(lines)

    def timed(label: str, cmd: list[str], timeout: int) -> list[str]:
        """Run a command and return [label, status, elapsed]."""
        start = time.perf_counter()
        rc, _out, err = run(cmd, timeout=timeout)
        elapsed = time.perf_counter() - start
        status = "✓" if rc == 0 else "✗"
        if "timed out" in err:
            status = "⚠"
            elapsed = float(timeout)
        return [label, status, f"{elapsed:.2f}s"]

    lines.append(md_subsection("Evaluation (attribute resolution)"))
    eval_trials: list[tuple[str, list[str], int]] = [
        ("nix flake show", ["nix", "flake", "show"], 120),
    ]
    for label, attr in [
        ("packages.x86_64-linux", "packages.x86_64-linux"),
        ("apps.x86_64-linux", "apps.x86_64-linux"),
        ("checks.x86_64-linux", "checks.x86_64-linux"),
    ]:
        eval_trials.append(
            (label, ["nix", "eval", f".#{attr}", "--apply", "builtins.attrNames"], 60)
        )
    lines.append(
        md_table(["Command", "Result", "Time"], [timed(*t) for t in eval_trials])
    )

    lines.append(md_subsection("Build (realisation)"))
    build_trials = [("nix flake check", ["nix", "flake", "check", "--no-build"], 120)]
    lines.append(
        md_table(["Command", "Result", "Time"], [timed(*t) for t in build_trials])
    )
    return "\n".join(lines)


def section_tech_debt() -> str:
    """Section 26: Technical Debt Score."""
    lines = [md_section(26, "Technical Debt Score")]

    checks: list[tuple[str, str, bool]] = []

    files = find_nix_files()
    fan_out, _fan_in = parse_imports_from_tree(files)
    has_cycle = False
    visited: set = set()
    stack: set = set()

    def has_cycle_dfs(node: Path) -> bool:
        """DFS cycle detection in the import graph."""
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

    rc, out, _ = run(
        [
            "rg",
            "-l",
            "parseEnv",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=10,
    )
    parseenv_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Architecture",
            f"parseEnv imported from {parseenv_files} files",
            parseenv_files <= 4,
        )
    )

    rc, out, _ = run(
        [
            "rg",
            "-l",
            "x86_64-linux",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=10,
    )
    x86_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Portability",
            f"{x86_files} architecture-specific literals (x86_64-linux)",
            x86_files <= 5,
        )
    )

    rc, out, _ = run(
        [
            "rg",
            "-l",
            "proj/angst",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=10,
    )
    repo_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Portability",
            f"{repo_files} repository path literals (proj/angst)",
            repo_files <= 3,
        )
    )

    rc, out, _ = run(
        [
            "rg",
            "-l",
            "/nix/store",
            "--type",
            "nix",
            "-g",
            "!.git",
            "-g",
            "!result",
            "-g",
            "!tools/vm/**",
            "-g",
            "!tools/shell/**",
        ],
        timeout=10,
    )
    store_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        ("Portability", f"{store_files} files reference /nix/store", store_files <= 1)
    )

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

    statix_ok = True
    if has_cmd("statix"):
        rc, _, _ = run(["statix", "check", "."], timeout=30)
        statix_ok = rc == 0
    checks.append(("Evaluation", "Statix clean", statix_ok))

    deadnix_ok = True
    if has_cmd("deadnix"):
        rc, _, _ = run(
            ["deadnix", ".", "--quiet", "--no-lambda-pattern-names"], timeout=30
        )
        deadnix_ok = rc == 0
    checks.append(("Evaluation", "No dead code (deadnix clean)", deadnix_ok))

    categories: dict[str, list[tuple[str, bool]]] = {}
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
