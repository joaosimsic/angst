"""Sections 23-26: dead code, anti-patterns, eval cost, tech debt."""

import time
from pathlib import Path

from ..util import (
    REPO,
    find_nix_files,
    has_cmd,
    md_section,
    md_subsection,
    md_table,
    parse_imports_from_tree,
    rg,
    run,
)


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

    rc, out, _ = rg(["-l", "parseEnv"], timeout=10)
    parseenv_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Architecture",
            f"parseEnv imported from {parseenv_files} files",
            parseenv_files <= 4,
        )
    )

    rc, out, _ = rg(["-l", "x86_64-linux"], timeout=10)
    x86_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Portability",
            f"{x86_files} architecture-specific literals (x86_64-linux)",
            x86_files <= 5,
        )
    )

    rc, out, _ = rg(["-l", "proj/angst"], timeout=10)
    repo_files = len(out.strip().splitlines()) if rc == 0 and out.strip() else 0
    checks.append(
        (
            "Portability",
            f"{repo_files} repository path literals (proj/angst)",
            repo_files <= 3,
        )
    )

    rc, out, _ = rg(["-l", "/nix/store"], timeout=10)
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
