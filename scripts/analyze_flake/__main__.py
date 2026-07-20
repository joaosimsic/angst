#!/usr/bin/env python3
"""angst flake analysis — Markdown report.

Usage:
    python -m scripts.analyze_flake [--no-eval-cost] [--no-graph] [-o output.md]

Outputs a Markdown report to stdout (or -o FILE).
"""

import argparse
import re
from datetime import datetime

from .sections import (
    section_overview,
    section_file_size_heatmap,
    section_directory_breakdown,
    section_attribute_surface,
    section_config_matrix,
    section_render_coverage,
    section_dependency_fan,
    section_coupling_graph,
    section_build_depth,
    section_duplication,
    section_hardcoded_strings,
    section_domain_inventory_condensed,
    section_theme_inventory_condensed,
    section_capabilities_inventory_condensed,
    section_toolchain_inventory_condensed,
    section_host_inventory,
    section_option_inventory,
    section_nix_idiom,
    section_conditional_builtins,
    section_complexity_metrics,
    section_interesting_complexity,
    section_error_handling,
    section_dead_code,
    section_anti_patterns,
    section_eval_cost,
    section_tech_debt,
    section_hotspot_table,
    section_stability_index,
    section_theme_domain_coverage,
    section_domain_features,
    section_check_results,
    section_render_output_sizes,
    section_growth_velocity,
    section_token_usage,
)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse CLI arguments."""
    p = argparse.ArgumentParser(description="angst flake analysis — Markdown report")
    p.add_argument(
        "--no-eval-cost", action="store_true", help="Skip evaluation timing (opt-out)"
    )
    p.add_argument(
        "--no-graph", action="store_true", help="Skip Mermaid dependency graph"
    )
    p.add_argument(
        "-o", "--output", help="Write report to FILE instead of stdout"
    )
    return p.parse_args(argv)


def main() -> None:
    """Entry point: generate the full Markdown analysis report."""
    args = parse_args()
    no_eval_cost = args.no_eval_cost
    no_graph = args.no_graph
    out_file = args.output

    def slug(s: str) -> str:
        """Convert a heading to an anchor slug."""
        s = s.lower()
        s = re.sub(r"[^a-z0-9]+", "-", s)
        return s.strip("-")

    section_fns: list[tuple[str, str]] = [
        ("1. Overview", section_overview(no_eval_cost)),
        ("2. File Size Heatmap (top 30)", section_file_size_heatmap()),
        ("3. Directory Size Breakdown", section_directory_breakdown()),
        ("4. Attribute Surface", section_attribute_surface()),
        ("5. Configuration Matrix", section_config_matrix()),
        ("6. Domain Feature Coverage", section_render_coverage()),
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
        ("28. Stability Index", section_stability_index()),
        ("29. Theme × Domain Coverage", section_theme_domain_coverage(no_eval_cost)),
        ("30. Domain Features", section_domain_features()),
        ("31. Check Results Breakdown", section_check_results(no_eval_cost)),
        ("32. Rendered Output Sizes", section_render_output_sizes()),
        ("33. Growth Velocity", section_growth_velocity()),
        ("34. Theme Token Usage Audit", section_token_usage()),
    ]

    def emit(text: str) -> None:
        if out_file:
            with open(out_file, "w") as f:
                f.write(text)
        else:
            print(text, end="")

    report = ""
    report += "# angst flake analysis\n\n"
    report += f"*Generated: {datetime.now():%Y-%m-%d %H:%M}*\n\n"

    report += "## Table of Contents\n\n"
    for heading, _ in section_fns:
        num_dot = heading.index(".")
        rest = heading[num_dot + 1 :].strip()
        report += f"- [{heading}](#{slug(rest)})\n"
    report += "\n"

    for heading, result in section_fns:
        if result:
            report += result

    report += "\n"
    report += "---\n"
    report += "\n*Analysis complete.*\n"

    emit(report)


if __name__ == "__main__":
    main()
