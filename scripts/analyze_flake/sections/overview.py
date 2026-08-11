"""Sections 1-6: overview, size heatmap, directory breakdown, attributes, matrix, coverage."""

from collections import Counter
from pathlib import Path
from typing import Any

from ..util import (
    REPO,
    find_nix_files,
    md_section,
    md_table,
    nix_eval_attr_names,
    read_nix,
    run,
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
    counts: Counter = Counter()
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
