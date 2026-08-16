"""Analysis sections for the angst flake report.

Re-exports every section_* function from its submodule so that callers
(such as ``__main__.py``) keep a single import surface.
"""

from .analysis import (
    section_complexity_metrics,
    section_conditional_builtins,
    section_error_handling,
    section_interesting_complexity,
    section_nix_idiom,
    section_option_inventory,
)
from .churn import section_hotspot_table, section_stability_index
from .coverage import (
    section_check_results,
    section_domain_features,
    section_growth_velocity,
    section_render_output_sizes,
    section_theme_domain_coverage,
    section_token_usage,
)
from .graph import (
    section_build_depth,
    section_coupling_graph,
    section_dependency_fan,
)
from .inventory import (
    section_capabilities_inventory_condensed,
    section_domain_inventory_condensed,
    section_duplication,
    section_hardcoded_strings,
    section_host_inventory,
    section_theme_inventory_condensed,
    section_toolchain_inventory_condensed,
)
from .overview import (
    section_attribute_surface,
    section_config_matrix,
    section_directory_breakdown,
    section_file_size_heatmap,
    section_overview,
    section_render_coverage,
)
from .quality import (
    section_anti_patterns,
    section_dead_code,
    section_eval_cost,
    section_tech_debt,
)

__all__ = [
    "section_overview",
    "section_file_size_heatmap",
    "section_directory_breakdown",
    "section_attribute_surface",
    "section_config_matrix",
    "section_render_coverage",
    "section_dependency_fan",
    "section_coupling_graph",
    "section_build_depth",
    "section_duplication",
    "section_hardcoded_strings",
    "section_domain_inventory_condensed",
    "section_theme_inventory_condensed",
    "section_capabilities_inventory_condensed",
    "section_toolchain_inventory_condensed",
    "section_host_inventory",
    "section_option_inventory",
    "section_nix_idiom",
    "section_conditional_builtins",
    "section_complexity_metrics",
    "section_interesting_complexity",
    "section_error_handling",
    "section_dead_code",
    "section_anti_patterns",
    "section_eval_cost",
    "section_tech_debt",
    "section_hotspot_table",
    "section_stability_index",
    "section_theme_domain_coverage",
    "section_domain_features",
    "section_check_results",
    "section_render_output_sizes",
    "section_growth_velocity",
    "section_token_usage",
]
