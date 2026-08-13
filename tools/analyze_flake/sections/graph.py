"""Sections 7-9: dependency fan, coupling graph, build depth."""

from collections import defaultdict
from pathlib import Path
from typing import Any

from ..util import (
    REPO,
    find_nix_files,
    md_code,
    md_section,
    md_subsection,
    md_table,
    parse_imports_from_tree,
)


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
    "domains",
    "themes",
    "toolchains",
    "hosts",
    "runtime",
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
