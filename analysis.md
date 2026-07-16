# angst flake analysis

*Generated: 2026-07-16 17:23*

## Table of Contents

- [1. Overview](#overview)
- [2. File Size Heatmap (top 30)](#file-size-heatmap-top-30)
- [3. Directory Size Breakdown](#directory-size-breakdown)
- [4. Attribute Surface](#attribute-surface)
- [5. Configuration Matrix](#configuration-matrix)
- [6. Render Coverage](#render-coverage)
- [7. Dependency Fan-in / Fan-out](#dependency-fan-in-fan-out)
- [8. Module Coupling Graph](#module-coupling-graph)
- [9. Build Graph Depth](#build-graph-depth)
- [10. Duplication Hotspots](#duplication-hotspots)
- [11. Hardcoded Strings Inventory](#hardcoded-strings-inventory)
- [12. Domain Inventory](#domain-inventory)
- [13. Theme Inventory](#theme-inventory)
- [14. Capabilities Inventory](#capabilities-inventory)
- [15. Toolchain Inventory](#toolchain-inventory)
- [16. Host Inventory](#host-inventory)
- [17. Option Inventory](#option-inventory)
- [18. Nix Idiom Usage](#nix-idiom-usage)
- [19. Conditional & Builtins Usage](#conditional-builtins-usage)
- [20. Complexity Metrics](#complexity-metrics)
- [21. "Interesting" Complexity Metrics](#interesting-complexity-metrics)
- [22. Error Handling](#error-handling)
- [23. Dead Code](#dead-code)
- [24. Anti-Patterns (statix)](#anti-patterns-statix)
- [25. Evaluation Cost](#evaluation-cost)
- [26. Technical Debt Score](#technical-debt-score)
- [27. Hotspot Table](#hotspot-table)
- [28. Stability Index](#stability-index)
- [29. Module Summary](#module-summary)
- [30. Theme × Domain Coverage](#theme-domain-coverage)
- [31. Domain Maturity Score](#domain-maturity-score)
- [32. Check Results Breakdown](#check-results-breakdown)
- [33. Rendered Output Sizes](#rendered-output-sizes)
- [34. Growth Velocity](#growth-velocity)
- [35. Theme Token Usage Audit](#theme-token-usage-audit)


## 1. Overview

| Metric | Value |
|---|---|
| Files | 139 .nix files, 6045 LOC |
| Rust | 2268 LOC (tools/vm + tools/shell) |
| Scripts | 333 LOC (bash) |
| Docs | 1294 LOC (openwiki) |
| Flake check | ✓ passed |

## 2. File Size Heatmap (top 30)

| LOC | File | Section |
|---|---|---|
| 423 | domains/terminal/zellij/render.nix | domains |
| 423 | domains/shell/starship/render.nix | domains |
| 388 | lib/flake/default.nix | lib |
| 341 | domains/git/lazygit/render.nix | domains |
| 218 | themes/default.nix | themes |
| 199 | lib/virtualisation/vm-profile.nix | lib |
| 190 | lib/flake/shared.nix | lib |
| 171 | flake.nix | root |
| 147 | domains/wm/i3/render.nix | domains |
| 130 | domains/shell/nushell/render.nix | domains |
| 128 | domains/launcher/rofi/render.nix | domains |
| 109 | lib/build/mkHome.nix | lib |
| 105 | domains/sql-client/sqlit/render.nix | domains |
| 104 | lib/domains/module.nix | lib |
| 102 | lib/checks/password.nix | lib |
| 91 | lib/domains/activation.nix | lib |
| 89 | domains/terminal/ghostty/render.nix | domains |
| 88 | lib/build/mkHost.nix | lib |
| 76 | domains/llm/opencode/render.nix | domains |
| 73 | lib/domains/scan.nix | lib |
| 64 | lib/domains/domain-config.nix | lib |
| 62 | domains/terminal/zellij/module.nix | domains |
| 61 | lib/flake/checks.nix | lib |
| 57 | lib/checks/desktop.nix | lib |
| 56 | hosts/ssh/home.nix | hosts |
| 55 | lib/flake/homeConfigurations.nix | lib |
| 54 | lib/nixos/default.nix | lib |
| 53 | capabilities/graphical.nix | capabilities |
| 51 | domains/editor/nvim/render.nix | domains |
| 50 | lib/checks/shell.nix | lib |

## 3. Directory Size Breakdown

| Directory | .nix files | LOC | Extra |
|---|---|---|---|
| lib/ | 41 | 2219 |  |
| domains/ | 41 | 2345 |  |
| toolchains/ | 21 | 277 |  |
| themes/ | 11 | 449 |  |
| capabilities/ | 10 | 294 |  |
| hosts/ | 11 | 255 |  |
| common/ | 3 | 35 |  |
| scripts/ | 0 | 0 |  (+2 .sh files, 333 LOC) |

## 4. Attribute Surface

| Output | Count | Entries |
|---|---|---|
| packages | 7 | angst, default, res, shell, vm, vm-cli, vm-run |
| devShells | 3 | dev, safe, vm |
| apps | 11 | analyze, angst, check, lint-desktop, lint-shell, lint-themes, render, shell... |
| checks | 9 | check-parse-env, check-password, home-theme-override-test, lint-desktop, lint-shell, lint-themes, theme-override, theme-rendered... |
| nixosConfig | 3 | default, generic, personal |
| homeConfig | 5 | user, user-theme-override-test, user@generic, user@personal, user@ssh |

## 5. Configuration Matrix

| Dimension | Count | Values |
|---|---|---|
| Hosts | 3 | generic, personal, ssh |
| Themes | 9 | catppuccin-mocha, github, gotham, kanagawa, lotus, miasma, monochrome, noctis, rose-pine |
| Architectures | 1 | x86_64-linux |
| Domains | 16 | 16 domains in 12 categories |

> **Possible host/theme configurations:** 3 × 9 = 27

## 6. Render Coverage

| Feature | Count | Coverage |
|---|---|---|
| render module | 13 | 81% |
| home module | 11 | 68% |
| nixos module | 1 | 6% |
| activation script | 0 | 0% |
| check files | 0 | 0% |
| **total domains** | 16 | 100% |

## 7. Dependency Fan-in / Fan-out


### Most imported modules (fan-in)

| Direct | Transitive | File |
|---|---|---|
| 20 | 20 | lib/toolchain.nix |
| 6 | 7 | lib/parseEnv.nix |
| 4 | 4 | lib/domains/default.nix |
| 4 | 9 | lib/checks/theme/assertions.nix |
| 3 | 4 | themes/default.nix |
| 2 | 2 | lib/flake/shared.nix |
| 2 | 2 | common/user.nix |
| 2 | 3 | lib/home/fonts.nix |
| 2 | 4 | lib/treesitter.nix |
| 1 | 1 | lib/build/scanHosts.nix |
| 1 | 1 | common/home.nix |
| 1 | 1 | lib/build/mkHome.nix |
| 1 | 1 | lib/build/mkHost.nix |
| 1 | 1 | lib/flake/default.nix |
| 1 | 1 | hosts/generic/user.nix |

### Largest dependency fan-out

| Imports | File |
|---|---|
| 12 | lib/flake/default.nix |
| 8 | flake.nix |
| 4 | lib/build/mkHome.nix |
| 4 | lib/flake/checks.nix |
| 3 | lib/domains/default.nix |
| 2 | lib/build/mkHost.nix |
| 1 | capabilities/graphical.nix |
| 1 | hosts/generic/default.nix |
| 1 | hosts/personal/default.nix |
| 1 | hosts/ssh/default.nix |
| 1 | lib/checks/parseEnv.nix |
| 1 | lib/checks/theme/default.nix |
| 1 | lib/checks/theme/rendered.nix |
| 1 | lib/checks/theme/semanticDistinct.nix |
| 1 | lib/domains/module.nix |

## 8. Module Coupling Graph


### Import tree (from flake.nix)

```
flake.nix
├── lib/build/scanHosts.nix
├── lib/domains/default.nix
│   ├── lib/domains/scan.nix
│   ├── lib/domains/activation.nix
│   └── lib/domains/module.nix
│       └── lib/checks/theme/assertions.nix
├── common/home.nix
├── lib/flake/shared.nix
│   └── lib/treesitter.nix
├── lib/build/mkHome.nix
│   ├── lib/parseEnv.nix
│   ├── themes/default.nix
│   │   └── themes/schema.nix
│   ├── lib/domains/default.nix
│   │   ├── lib/domains/scan.nix
│   │   ├── lib/domains/activation.nix
│   │   └── lib/domains/module.nix
│   │       └── lib/checks/theme/assertions.nix
│   └── lib/home/themeModule.nix
├── lib/build/mkHost.nix
│   ├── lib/parseEnv.nix
│   └── lib/domains/default.nix
│       ├── lib/domains/scan.nix
│       ├── lib/domains/activation.nix
│       └── lib/domains/module.nix
│           └── lib/checks/theme/assertions.nix
├── lib/flake/default.nix
│   ├── lib/parseEnv.nix
│   ├── lib/domains/default.nix
│   │   ├── lib/domains/scan.nix
│   │   ├── lib/domains/activation.nix
│   │   └── lib/domains/module.nix
│   │       └── lib/checks/theme/assertions.nix
│   ├── themes/default.nix
│   │   └── themes/schema.nix
│   ├── lib/home/fonts.nix
│   ├── lib/checks/theme/assertions.nix
│   ├── lib/checks/theme/context.nix
│   ├── lib/checks/desktop.nix
│   ├── lib/checks/shell.nix
│   ├── lib/checks/theme/rendered.nix
│   │   └── lib/checks/theme/assertions.nix
│   ├── lib/flake/homeConfigurations.nix
│   │   └── lib/parseEnv.nix
│   ├── lib/flake/checks.nix
│   │   ├── lib/checks/theme/semanticDistinct.nix
│   │   │   └── lib/checks/theme/assertions.nix
│   │   ├── lib/checks/theme/override.nix
│   │   ├── lib/checks/parseEnv.nix
│   │   │   └── lib/parseEnv.nix
│   │   └── lib/checks/password.nix
│   └── lib/flake/shared.nix
│       └── lib/treesitter.nix
└── lib/parseEnv.nix
```

### Architectural layer validation


Allowed direction (foundational → specific):

```
flake.nix
 ↓
lib
 ↓
common
 ↓
capabilities
 ↓
domains
 ↓
themes
 ↓
toolchains
 ↓
hosts
 ↓
scripts
```


**3 violations detected:**

- `capabilities/graphical.nix` → `themes/default.nix`
- `lib/build/mkHome.nix` → `themes/default.nix`
- `lib/flake/default.nix` → `themes/default.nix`

### Module Dependency Graph (Mermaid)

```mermaid
flowchart LR
    n0["flake.nix"] --> n1["lib/build/scanHosts.nix"]
    n0["flake.nix"] --> n2["lib/domains/default.nix"]
    n2["lib/domains/default.nix"] --> n3["lib/domains/scan.nix"]
    n2["lib/domains/default.nix"] --> n4["lib/domains/activation.nix"]
    n2["lib/domains/default.nix"] --> n5["lib/domains/module.nix"]
    n5["lib/domains/module.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n0["flake.nix"] --> n7["common/home.nix"]
    n0["flake.nix"] --> n8["lib/flake/shared.nix"]
    n8["lib/flake/shared.nix"] --> n9["lib/treesitter.nix"]
    n0["flake.nix"] --> n10["lib/build/mkHome.nix"]
    n10["lib/build/mkHome.nix"] --> n11["lib/parseEnv.nix"]
    n10["lib/build/mkHome.nix"] --> n12["themes/default.nix"]
    n12["themes/default.nix"] --> n13["themes/schema.nix"]
    n10["lib/build/mkHome.nix"] --> n2["lib/domains/default.nix"]
    n10["lib/build/mkHome.nix"] --> n14["lib/home/themeModule.nix"]
    n0["flake.nix"] --> n15["lib/build/mkHost.nix"]
    n15["lib/build/mkHost.nix"] --> n11["lib/parseEnv.nix"]
    n15["lib/build/mkHost.nix"] --> n2["lib/domains/default.nix"]
    n0["flake.nix"] --> n16["lib/flake/default.nix"]
    n16["lib/flake/default.nix"] --> n11["lib/parseEnv.nix"]
    n16["lib/flake/default.nix"] --> n2["lib/domains/default.nix"]
    n16["lib/flake/default.nix"] --> n12["themes/default.nix"]
    n16["lib/flake/default.nix"] --> n17["lib/home/fonts.nix"]
    n16["lib/flake/default.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n16["lib/flake/default.nix"] --> n18["lib/checks/theme/context.nix"]
    n16["lib/flake/default.nix"] --> n19["lib/checks/desktop.nix"]
    n16["lib/flake/default.nix"] --> n20["lib/checks/shell.nix"]
    n16["lib/flake/default.nix"] --> n21["lib/checks/theme/rendered.nix"]
    n21["lib/checks/theme/rendered.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n16["lib/flake/default.nix"] --> n22["lib/flake/homeConfigurations.nix"]
    n22["lib/flake/homeConfigurations.nix"] --> n11["lib/parseEnv.nix"]
    n16["lib/flake/default.nix"] --> n23["lib/flake/checks.nix"]
    n23["lib/flake/checks.nix"] --> n24["lib/checks/theme/semanticDistinct.nix"]
    n24["lib/checks/theme/semanticDistinct.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n23["lib/flake/checks.nix"] --> n25["lib/checks/theme/override.nix"]
    n23["lib/flake/checks.nix"] --> n26["lib/checks/parseEnv.nix"]
    n26["lib/checks/parseEnv.nix"] --> n11["lib/parseEnv.nix"]
    n23["lib/flake/checks.nix"] --> n27["lib/checks/password.nix"]
    n16["lib/flake/default.nix"] --> n8["lib/flake/shared.nix"]
    n0["flake.nix"] --> n11["lib/parseEnv.nix"]
```

## 9. Build Graph Depth


Maximum dependency depth from **flake.nix**: **4**

Longest import chain:

```
flake.nix
 └─ lib/build/mkHome.nix
     └─ lib/domains/default.nix
         └─ lib/domains/module.nix
             └─ lib/checks/theme/assertions.nix
```

## 10. Duplication Hotspots


### userEnv parsing (parseEnv.nix)

- `flake.nix`
- `lib/build/mkHome.nix`
- `lib/build/mkHost.nix`
- `lib/checks/parseEnv.nix`
- `lib/flake/checks.nix`
- `lib/flake/default.nix`
- `lib/flake/homeConfigurations.nix`

### "x86_64-linux" hardcoded

- `hosts/personal/default.nix`
- `hosts/ssh/home.nix`
- `hosts/ssh/default.nix`
- `hosts/generic/default.nix`
- `flake.nix`

### "proj/angst" hardcoded

- `hosts/personal/default.nix`
- `hosts/ssh/default.nix`
- `hosts/generic/default.nix`
- `flake.nix`
- `lib/build/mkHome.nix`
- `lib/build/mkHost.nix`
- `lib/virtualisation/detect.nix`
- `lib/flake/default.nix`
- `lib/virtualisation/is-qemu-vm.nix`
- `lib/flake/homeConfigurations.nix`

### "allowUnfree" hardcoded

- `flake.nix`
- `lib/nixos/default.nix`
- `lib/build/mkHome.nix`

### Key re-imports (dedup candidates)

- **parseEnv**: 7 files import it
  - `flake.nix`
  - `lib/flake/checks.nix`
  - `lib/flake/default.nix`
  - `lib/flake/homeConfigurations.nix`
  - `lib/build/mkHome.nix`
  - `lib/build/mkHost.nix`
  - `lib/checks/parseEnv.nix`
- **domains/default**: 4 files import it
  - `flake.nix`
  - `lib/build/mkHome.nix`
  - `lib/flake/default.nix`
  - `lib/build/mkHost.nix`
- **themes/default**: 3 files import it
  - `lib/build/mkHome.nix`
  - `lib/flake/default.nix`
  - `capabilities/graphical.nix`
- **shared.nix**: 2 files import it
  - `flake.nix`
  - `lib/flake/default.nix`

## 11. Hardcoded Strings Inventory

| String | Occurrences | Files | Description |
|---|---|---|---|
| "angst" | 75 | 26 | project name |
| "ANGST" | 39 | 11 | env var prefix |
| "nixpkgs" | 18 | 6 | flake input |
| "home-manager" | 12 | 6 | flake input |
| "proj/angst" | 11 | 10 | repo path |
| "x86_64" | 5 | 5 | architecture |
| "allowUnfree" | 3 | 3 | nixpkgs config |
| "generic" | 1 | 1 | default host |
| "monochrome" | 2 | 2 | default theme |
| "NIX_" | 5 | 2 | nix env vars |
| "ANGST_" | 39 | 11 | angst env vars |

## 12. Domain Inventory

| Category | Domains | Names | Render | Module | LOC |
|---|---|---|---|---|---|
| bar | 1 | i3status | 1 | 1 | 46 |
| editor | 1 | nvim | 1 | 1 | 75 |
| files | 1 | yazi | 1 | 1 | 46 |
| git | 1 | lazygit | 1 | 0 | 346 |
| http-client | 1 | posting | 1 | 0 | 52 |
| launcher | 1 | rofi | 1 | 1 | 148 |
| llm | 2 | cursor-cli,opencode | 1 | 0 | 86 |
| session | 1 | x11 | 0 | 1 | 21 |
| shell | 2 | nushell,starship | 2 | 2 | 589 |
| sql-client | 1 | sqlit | 1 | 0 | 110 |
| terminal | 3 | ghostty,tmux,zellij | 2 | 3 | 613 |
| wm | 1 | i3 | 1 | 1 | 213 |

## 13. Theme Inventory

> **See `nix flake show` for the full list.**

- **9 themes**, 226 total LOC

  - `catppuccin-mocha` — 27 LOC
  - `github` — 28 LOC
  - `gotham` — 28 LOC
  - `kanagawa` — 27 LOC
  - `lotus` — 28 LOC
  - `miasma` — 30 LOC
  - `monochrome` — 15 LOC (default)
  - `noctis` — 15 LOC
  - `rose-pine` — 28 LOC

## 14. Capabilities Inventory

> **See `nix flake show` for the full list.**

- **9 capabilities**, 272 total LOC

  - `audio` — 28 LOC
  - `clipboard` — 22 LOC
  - `container` — 42 LOC
  - `git` — 21 LOC
  - `graphical` — 53 LOC
  - `monitoring` — 21 LOC
  - `network` — 23 LOC
  - `search` — 23 LOC
  - `ssh` — 39 LOC

## 15. Toolchain Inventory

> **See `nix flake show` for the full list.**

- **20 toolchains**, 262 total LOC

  - `bash` — 11 LOC
  - `blade` — 14 LOC
  - `c` — 13 LOC
  - `clojure` — 13 LOC
  - `conf` — 8 LOC
  - `css` — 8 LOC
  - `docker` — 12 LOC
  - `go` — 13 LOC
  - `html` — 8 LOC
  - `java` — 13 LOC
  - `javascript` — 25 LOC
  - `json` — 9 LOC
  - `lua` — 12 LOC
  - `nix` — 21 LOC
  - `php` — 26 LOC
  - `python` — 16 LOC
  - `rust` — 13 LOC
  - `terraform` — 9 LOC
  - `toml` — 9 LOC
  - `xml` — 9 LOC

## 16. Host Inventory


- **generic/**
  - `configuration.nix` — 25 LOC
  - `default.nix` — 7 LOC
  - `hardware.nix` — 40 LOC
  - `home.nix` — 10 LOC
  - `user.nix` — 8 LOC

- **personal/**
  - `configuration.nix` — 35 LOC
  - `default.nix` — 23 LOC
  - `hardware.nix` — 35 LOC
  - `home.nix` — 10 LOC

- **ssh/**
  - `default.nix` — 6 LOC
  - `home.nix` — 56 LOC

## 17. Option Inventory

| Construct | Count |
|---|---|
| mkOption | 7 |
| mkEnableOption | 11 |
| mkIf | 33 |

### Option namespace references

| Namespace | References |
|---|---|
| capabilities | 9 |
| domains | 2 |
| angst | 1 |
| font | 1 |
| toolchains | 1 |
| theme | 1 |
| domainConfig | 1 |

## 18. Nix Idiom Usage

| Idiom | Count |
|---|---|
| lib.mkIf | 31 |
| lib.mkForce | 21 |
| lib.mkDefault | 12 |
| lib.mkEnableOption | 11 |
| lib.substring | 10 |
| lib.concatMap | 5 |
| lib.mapAttrs | 3 |
| lib.filterAttrs | 3 |
| lib.nameValuePair | 3 |
| lib.listToAttrs | 3 |
| lib.genAttrs | 1 |
| lib.optional | 1 |
| lib.optionalAttrs | 0 |
| lib.mkMerge | 0 |
| lib.pipe | 0 |
| lib.foldl' | 0 |
| lib.flatten | 0 |
| lib.zipAttrsWith | 0 |

## 19. Conditional & Builtins Usage


### Conditional logic

| Construct | Count | Files |
|---|---|---|
| mkIf | 33 | 28 |
| mkDefault | 12 | 4 |
| mkForce | 21 | 6 |
| mkOption | 7 | 7 |
| mkEnableOption | 11 | 10 |

### Builtins frequency (top 15)

| Builtin | Count |
|---|---|
| builtins.getEnv | 23 |
| builtins.pathExists | 21 |
| builtins.throw | 7 |
| builtins.readDir | 7 |
| builtins.attrNames | 7 |
| builtins.head | 5 |
| builtins.filter | 4 |
| builtins.readFile | 4 |
| builtins.stringLength | 3 |
| builtins.toJSON | 3 |
| builtins.substring | 2 |
| builtins.match | 1 |
| builtins.removeAttrs | 1 |
| builtins.isString | 1 |
| builtins.isAttrs | 1 |

## 20. Complexity Metrics


### All files with non-trivial complexity

| Score | File | Contributing factors |
|---|---|---|
| 7 | `themes/default.nix` | depth=3, interp=27, LOC=218 |
| 7 | `lib/flake/default.nix` | depth=2, interp=54, LOC=388 |
| 7 | `domains/shell/starship/render.nix` | depth=2, interp=32, LOC=423 |
| 7 | `domains/shell/nushell/render.nix` | depth=20, interp=72, LOC=130 |
| 6 | `lib/virtualisation/vm-profile.nix` | interp=12, cond=14, LOC=199 |
| 6 | `lib/domains/module.nix` | depth=4, interp=18, LOC=104 |
| 6 | `domains/terminal/zellij/render.nix` | interp=167, LOC=423 |
| 5 | `lib/domains/activation.nix` | depth=2, interp=31, LOC=91 |
| 5 | `domains/wm/i3/render.nix` | depth=2, interp=43, LOC=147 |
| 4 | `lib/flake/shared.nix` | interp=25, LOC=190 |
| 4 | `lib/checks/password.nix` | depth=3, LOC=102 |
| 4 | `flake.nix` | depth=2, interp=10, LOC=171 |
| 4 | `domains/sql-client/sqlit/render.nix` | interp=48, LOC=105 |
| 4 | `domains/git/lazygit/render.nix` | interp=11, LOC=341 |
| 3 | `domains/terminal/ghostty/render.nix` | interp=28, LOC=89 |
| 3 | `domains/llm/opencode/render.nix` | interp=50 |
| 2 | `lib/treesitter.nix` | depth=2, interp=15 |
| 2 | `lib/nixos/default.nix` | cond=7 |
| 2 | `lib/domains/scan.nix` | depth=2, interp=9 |
| 2 | `lib/domains/domain-config.nix` | depth=2, interp=14 |
| 2 | `lib/build/mkHome.nix` | depth=2, LOC=109 |
| 1 | `lib/virtualisation/runtime.nix` | cond=4 |
| 1 | `lib/virtualisation/host-mount.nix` | interp=9 |
| 1 | `lib/parseEnv.nix` | depth=2 |
| 1 | `lib/checks/theme/assertions.nix` | depth=2 |
| 1 | `lib/checks/shell.nix` | interp=7 |
| 1 | `lib/checks/desktop.nix` | interp=9 |
| 1 | `lib/build/mkHost.nix` | LOC=88 |
| 1 | `hosts/generic/hardware.nix` | cond=3 |
| 1 | `hosts/generic/configuration.nix` | cond=4 |
| 1 | `domains/wm/i3/module.nix` | interp=6 |
| 1 | `domains/launcher/rofi/render.nix` | LOC=128 |
| 1 | `domains/http-client/posting/render.nix` | interp=10 |
| 1 | `domains/files/yazi/render.nix` | interp=9 |
| 1 | `domains/editor/nvim/render.nix` | interp=13 |
| 1 | `capabilities/default.nix` | depth=2 |

## 21. "Interesting" Complexity Metrics


### Deepest Attrset Nesting

| Value | File |
|---|---|
| 7 | `domains/terminal/zellij/render.nix` |
| 6 | `lib/virtualisation/vm-profile.nix` |
| 6 | `lib/flake/default.nix` |
| 6 | `capabilities/graphical.nix` |
| 5 | `lib/virtualisation/vm-variant.nix` |
| 5 | `hosts/ssh/home.nix` |
| 5 | `domains/terminal/zellij/module.nix` |
| 5 | `domains/editor/nvim/render.nix` |

### Most Rec Blocks

| Value | File |
|---|---|
| 1 | `lib/build/mkHome.nix` |

### Most With Blocks

| Value | File |
|---|---|
| 6 | `toolchains/rust.nix` |
| 6 | `toolchains/python.nix` |
| 6 | `toolchains/java.nix` |
| 6 | `toolchains/go.nix` |
| 6 | `toolchains/clojure.nix` |
| 5 | `toolchains/php.nix` |
| 5 | `toolchains/nix.nix` |
| 5 | `toolchains/lua.nix` |

### Deepest Mkif Nesting

| Value | File |
|---|---|
| 1 | `lib/domains/domain-config.nix` |

### Largest Attrset

| Value | File |
|---|---|
| 159 | `domains/shell/starship/render.nix` |
| 61 | `lib/virtualisation/vm-profile.nix` |
| 56 | `domains/llm/opencode/render.nix` |
| 44 | `lib/flake/default.nix` |
| 41 | `themes/default.nix` |
| 29 | `flake.nix` |
| 14 | `themes/miasma.nix` |
| 13 | `themes/rose-pine.nix` |

### Largest List

| Value | File |
|---|---|
| 379 | `domains/shell/starship/render.nix` |
| 287 | `lib/flake/default.nix` |
| 203 | `domains/git/lazygit/render.nix` |
| 200 | `themes/default.nix` |
| 148 | `lib/flake/shared.nix` |
| 144 | `lib/virtualisation/vm-profile.nix` |
| 113 | `domains/launcher/rofi/render.nix` |
| 112 | `flake.nix` |

### Longest String (Lines)

| Value | File |
|---|---|
| 326 | `domains/git/lazygit/render.nix` |
| 145 | `domains/terminal/zellij/render.nix` |
| 103 | `domains/shell/nushell/render.nix` |
| 102 | `domains/wm/i3/render.nix` |
| 97 | `domains/launcher/rofi/render.nix` |
| 49 | `lib/checks/password.nix` |
| 48 | `domains/shell/starship/render.nix` |
| 39 | `domains/terminal/zellij/module.nix` |

### Deepest Function Pipeline (|>)

| Value | File |
|---|---|

## 22. Error Handling

| Construct | Count |
|---|---|
| throw | 11 |
| abort | 0 |
| assert | 6 |

### Throw locations

- `themes/default.nix:131:      builtins.throw "Theme '${name}' missing tokens: ${`
- `themes/default.nix:135:      builtins.throw "Theme '${name}' has invalid hex for: ${`
- `themes/default.nix:215:      builtins.throw "Unknown theme '${name}'. Available themes: ${`
- `flake.nix:149:              or (throw "HOST '${hostname}' not found. Available: ${toString (builtins.attrNames configs)}");`
- `lib/checks/theme/context.nix:21:      builtins.throw "No alternate theme available for override test (host uses ${hostTheme})"`
- `lib/checks/theme/override.nix:20:  throw "expected config.theme = ${overrideTheme}, got ${theme}"`
- `lib/checks/theme/override.nix:22:  throw "theme override did not reach rendered ghostty colors (expected ${overrideTheme} background.variant)"`
- `lib/domains/scan.nix:18:      builtins.throw "domains/${category}/${name}/meta.nix: 'xdg' and 'xdgFile' are mutually exclusive"`
- `lib/domains/scan.nix:20:      builtins.throw "domains/${category}/${name}/meta.nix: must set 'xdg', 'xdgFile', or 'customXdg = true'"`
- `lib/flake/default.nix:93:      builtins.throw "Unknown domain render output: ${outputPath}"`

## 23. Dead Code

✓ No dead code detected.

## 24. Anti-Patterns (statix)

✓ No anti-patterns detected.

## 25. Evaluation Cost


### Evaluation (attribute resolution)

| Command | Result | Time |
|---|---|---|
| nix flake show | ✓ | 2.15s |
| packages.x86_64-linux | ✓ | 0.05s |
| apps.x86_64-linux | ✓ | 0.05s |
| checks.x86_64-linux | ✓ | 0.05s |

### Build (realisation)

| Command | Result | Time |
|---|---|---|
| nix flake check | ✓ | 22.82s |

## 26. Technical Debt Score


### Architecture

- ✓ No cyclic imports
- ⚠ parseEnv imported from 7 files

### Portability

- ✓ 5 architecture-specific literals (x86_64-linux)
- ⚠ 10 repository path literals (proj/angst)
- ✓ 1 files reference /nix/store

### Configuration

- ✓ All domains have meta.nix

### Evaluation

- ✓ Statix clean
- ✓ No dead code (deadnix clean)

## 27. Hotspot Table

> Cross-references file size, git churn, dependency counts, and complexity into a single view.

> **Columns**: LOC (size), Churn (commits/year), Imports (fan-out), Dependents (fan-in),
> Complexity (derived from nesting depth, string interpolation, conditional count).

| File | LOC | Churn | Imports | Dependents | Complexity | Score |
|---|---|---|---|---|---|---|
| `domains/terminal/zellij/render.nix` | 423 | 20 | 0 | 0 | High | 6 |
| `domains/shell/starship/render.nix` | 423 | 14 | 0 | 0 | Very High | 7 |
| `lib/flake/default.nix` | 388 | 32 | 12 | 1 | Very High | 7 |
| `domains/git/lazygit/render.nix` | 341 | 2 | 0 | 0 | Medium | 4 |
| `themes/default.nix` | 218 | 12 | 1 | 3 | Very High | 7 |
| `lib/virtualisation/vm-profile.nix` | 199 | 7 | 0 | 0 | High | 6 |
| `lib/flake/shared.nix` | 190 | 14 | 1 | 2 | Medium | 4 |
| `flake.nix` | 171 | 29 | 8 | 0 | Medium | 4 |
| `domains/wm/i3/render.nix` | 147 | 3 | 0 | 0 | High | 5 |
| `domains/shell/nushell/render.nix` | 130 | 6 | 0 | 0 | Very High | 7 |
| `domains/launcher/rofi/render.nix` | 128 | 3 | 0 | 0 | Low | 1 |
| `lib/build/mkHome.nix` | 109 | 20 | 4 | 1 | Low | 2 |
| `domains/sql-client/sqlit/render.nix` | 105 | 7 | 0 | 0 | Medium | 4 |
| `lib/domains/module.nix` | 104 | 11 | 1 | 1 | High | 6 |
| `lib/checks/password.nix` | 102 | 1 | 0 | 1 | Medium | 4 |
| `lib/domains/activation.nix` | 91 | 10 | 0 | 1 | High | 5 |
| `domains/terminal/ghostty/render.nix` | 89 | 6 | 0 | 0 | Medium | 3 |
| `lib/build/mkHost.nix` | 88 | 12 | 2 | 1 | Low | 1 |
| `domains/llm/opencode/render.nix` | 76 | 4 | 0 | 0 | Medium | 3 |
| `lib/domains/scan.nix` | 73 | 3 | 0 | 1 | Low | 2 |
| `lib/domains/domain-config.nix` | 64 | 7 | 0 | 0 | Low | 2 |
| `domains/terminal/zellij/module.nix` | 62 | 3 | 0 | 0 | Minimal | 0 |
| `lib/flake/checks.nix` | 61 | 9 | 4 | 1 | Minimal | 0 |
| `lib/checks/desktop.nix` | 57 | 7 | 0 | 1 | Low | 1 |
| `hosts/ssh/home.nix` | 56 | 8 | 0 | 0 | Minimal | 0 |

## 28. Stability Index

> Cross-references git churn with file recency. **Hot** = high churn + recently modified,
> **Active** = moderate churn, **Stable** = low churn, **Archived** = no changes in 6+ months.

| File | Churn | Last changed | Label |
|---|---|---|---|
| `lib/flake/default.nix` | 32 | 2026-07-16 | Hot |
| `flake.nix` | 29 | 2026-07-13 | Hot |
| `domains/terminal/zellij/render.nix` | 20 | 2026-07-15 | Hot |
| `lib/build/mkHome.nix` | 20 | 2026-07-16 | Hot |
| `hosts/personal/default.nix` | 19 | 2026-07-13 | Hot |
| `hosts/personal/configuration.nix` | 16 | 2026-07-16 | Hot |
| `lib/flake/shared.nix` | 14 | 2026-07-13 | Hot |
| `domains/shell/starship/render.nix` | 14 | 2026-07-16 | Hot |
| `themes/miasma.nix` | 13 | 2026-07-16 | Hot |
| `lib/build/mkHost.nix` | 12 | 2026-07-16 | Hot |
| `themes/default.nix` | 12 | 2026-07-16 | Hot |
| `lib/domains/module.nix` | 11 | 2026-07-16 | Hot |
| `themes/catppuccin-mocha.nix` | 10 | 2026-07-10 | Hot |
| `themes/kanagawa.nix` | 10 | 2026-07-10 | Hot |
| `lib/domains/activation.nix` | 10 | 2026-07-16 | Hot |
| `toolchains/php.nix` | 9 | 2026-07-02 | Active |
| `domains/editor/nvim/module.nix` | 9 | 2026-07-06 | Active |
| `themes/monochrome.nix` | 9 | 2026-07-10 | Active |
| `themes/noctis.nix` | 9 | 2026-07-10 | Active |
| `domains/wm/i3/module.nix` | 9 | 2026-07-12 | Active |

## 29. Module Summary

> Per-domain availability of module types. ✓ = present, — = absent.

| Domain | HM | NixOS | Render | Activation |
|---|---|---|---|---|
| bar/i3status | ✓ | — | ✓ | — |
| editor/nvim | ✓ | — | ✓ | — |
| files/yazi | ✓ | — | ✓ | — |
| git/lazygit | — | — | ✓ | — |
| http-client/posting | — | — | ✓ | — |
| launcher/rofi | ✓ | — | ✓ | — |
| llm/cursor-cli | — | — | — | — |
| llm/opencode | — | — | ✓ | — |
| session/x11 | ✓ | — | — | — |
| shell/nushell | ✓ | — | ✓ | — |
| shell/starship | ✓ | — | ✓ | — |
| sql-client/sqlit | — | — | ✓ | — |
| terminal/ghostty | ✓ | — | ✓ | — |
| terminal/tmux | ✓ | — | — | — |
| terminal/zellij | ✓ | — | ✓ | — |
| wm/i3 | ✓ | ✓ | ✓ | — |

## 30. Theme × Domain Coverage

> ✓ = render produces output, ✗ = render throws, — = no render.nix

| Theme | bar/i3status | editor/nvim | files/yazi | git/lazygit | http-client/posting | launcher/rofi | llm/cursor-cli | llm/opencode | session/x11 | shell/nushell | shell/starship | sql-client/sqlit | terminal/ghostty | terminal/tmux | terminal/zellij | wm/i3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `catppuccin-mocha` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `github` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `gotham` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `kanagawa` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `lotus` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `miasma` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `monochrome` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `noctis` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `rose-pine` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ |

## 31. Domain Maturity Score

> Composite score per domain. 5 = Complete, 0 = Skeleton.

| Domain | Score | Label | render | module | nixos | activation | checks |
|---|---|---|---|---|---|---|---|
| wm/i3 | 3 | Rendering | ✓ | ✓ | ✓ | — | — |
| bar/i3status | 2 | Partial | ✓ | ✓ | — | — | — |
| editor/nvim | 2 | Partial | ✓ | ✓ | — | — | — |
| files/yazi | 2 | Partial | ✓ | ✓ | — | — | — |
| launcher/rofi | 2 | Partial | ✓ | ✓ | — | — | — |
| shell/nushell | 2 | Partial | ✓ | ✓ | — | — | — |
| shell/starship | 2 | Partial | ✓ | ✓ | — | — | — |
| terminal/ghostty | 2 | Partial | ✓ | ✓ | — | — | — |
| terminal/zellij | 2 | Partial | ✓ | ✓ | — | — | — |
| git/lazygit | 1 | Minimal | ✓ | — | — | — | — |
| http-client/posting | 1 | Minimal | ✓ | — | — | — | — |
| llm/opencode | 1 | Minimal | ✓ | — | — | — | — |
| session/x11 | 1 | Minimal | — | ✓ | — | — | — |
| sql-client/sqlit | 1 | Minimal | ✓ | — | — | — | — |
| terminal/tmux | 1 | Minimal | — | ✓ | — | — | — |
| llm/cursor-cli | 0 | Skeleton | — | — | — | — | — |

## 32. Check Results Breakdown

| Check | Result | Time | Details |
|---|---|---|---|
| `check-parse-env` | ✓ | 0.45s |  |
| `check-password` | ✓ | 1.67s |  |
| `home-theme-override-test` | ✓ | 13.00s |  |
| `lint-desktop` | ✓ | 2.00s |  |
| `lint-shell` | ✓ | 1.18s |  |
| `lint-themes` | ✓ | 0.50s |  |
| `theme-override` | ✓ | 1.15s |  |
| `theme-rendered` | ✓ | 0.47s |  |
| `theme-semantic-distinct` | ✓ | 0.45s |  |

**9 passed, 0 failed**


### Theme lint detail

```
Themes (9):
  catppuccin-mocha: ok
  github: ok
  gotham: ok
  kanagawa: ok
  lotus: ok
  miasma: ok
  monochrome: ok
  noctis: ok
  rose-pine: ok

Domain renders:
  domains/bar/i3status/config/config render + catppuccin-mocha: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + catppuccin-mocha: ok
  domains/files/yazi/config/theme.toml render + catppuccin-mocha: ok
  domains/git/lazygit/config/config.yml render + catppuccin-mocha: ok
  domains/http-client/posting/config/config.yaml render + catppuccin-mocha: ok
  domains/http-client/posting/config/themes/angst.yaml render + catppuccin-mocha: ok
  domains/launcher/rofi/config/config.rasi render + catppuccin-mocha: ok
  domains/launcher/rofi/config/theme.rasi render + catppuccin-mocha: ok
  domains/llm/opencode/config/tui.json render + catppuccin-mocha: ok
  domains/llm/opencode/config/themes/angst.json render + catppuccin-mocha: ok
  domains/shell/nushell/config/colors.nu render + catppuccin-mocha: ok
  domains/shell/starship/config/starship.toml render + catppuccin-mocha: ok
  domains/sql-client/sqlit/config/settings.json render + catppuccin-mocha: ok
  domains/sql-client/sqlit/config/themes/catppuccin-mocha.json render + catppuccin-mocha: ok
  domains/terminal/ghostty/config/config render + catppuccin-mocha: ok
  domains/terminal/ghostty/config/colors.conf render + catppuccin-mocha: ok
  domains/terminal/zellij/config/config.kdl render + catppuccin-mocha: ok
  domains/terminal/zellij/config/themes/angst.kdl render + catppuccin-mocha: ok
  domains/terminal/zellij/config/layouts/default.kdl render + catppuccin-mocha: ok
  domains/wm/i3/config/monitors.conf render + catppuccin-mocha: ok
  domains/wm/i3/config/config render + catppuccin-mocha: ok
  domains/bar/i3status/config/config render + github: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + github: ok
  domains/files/yazi/config/theme.toml render + github: ok
  domains/git/lazygit/config/config.yml render + github: ok
  domains/http-client/posting/config/config.yaml render + github: ok
  domains/http-client/posting/config/themes/angst.yaml render + github: ok
  domains/launcher/rofi/config/config.rasi render + github: ok
  domains/launcher/rofi/config/theme.rasi render + github: ok
  domains/llm/opencode/config/tui.json render + github: ok
  domains/llm/opencode/config/themes/angst.json render + github: ok
  domains/shell/nushell/config/colors.nu render + github: ok
  domains/shell/starship/config/starship.toml render + github: ok
  domains/sql-client/sqlit/config/settings.json render + github: ok
  domains/sql-client/sqlit/config/themes/github.json render + github: ok
  domains/terminal/ghostty/config/config render + github: ok
  domains/terminal/ghostty/config/colors.conf render + github: ok
  domains/terminal/zellij/config/config.kdl render + github: ok
  domains/terminal/zellij/config/themes/angst.kdl render + github: ok
  domains/terminal/zellij/config/layouts/default.kdl render + github: ok
  domains/wm/i3/config/monitors.conf render + github: ok
  domains/wm/i3/config/config render + github: ok
  domains/bar/i3status/config/config render + gotham: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + gotham: ok
  domains/files/yazi/config/theme.toml render + gotham: ok
  domains/git/lazygit/config/config.yml render + gotham: ok
  domains/http-client/posting/config/config.yaml render + gotham: ok
  domains/http-client/posting/config/themes/angst.yaml render + gotham: ok
  domains/launcher/rofi/config/config.rasi render + gotham: ok
  domains/launcher/rofi/config/theme.rasi render + gotham: ok
  domains/llm/opencode/config/tui.json render + gotham: ok
  domains/llm/opencode/config/themes/angst.json render + gotham: ok
  domains/shell/nushell/config/colors.nu render + gotham: ok
  domains/shell/starship/config/starship.toml render + gotham: ok
  domains/sql-client/sqlit/config/settings.json render + gotham: ok
  domains/sql-client/sqlit/config/themes/gotham.json render + gotham: ok
  domains/terminal/ghostty/config/config render + gotham: ok
  domains/terminal/ghostty/config/colors.conf render + gotham: ok
  domains/terminal/zellij/config/config.kdl render + gotham: ok
  domains/terminal/zellij/config/themes/angst.kdl render + gotham: ok
  domains/terminal/zellij/config/layouts/default.kdl render + gotham: ok
  domains/wm/i3/config/monitors.conf render + gotham: ok
  domains/wm/i3/config/config render + gotham: ok
  domains/bar/i3status/config/config render + kanagawa: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + kanagawa: ok
  domains/files/yazi/config/theme.toml render + kanagawa: ok
  domains/git/lazygit/config/config.yml render + kanagawa: ok
  domains/http-client/posting/config/config.yaml render + kanagawa: ok
  domains/http-client/posting/config/themes/angst.yaml render + kanagawa: ok
  domains/launcher/rofi/config/config.rasi render + kanagawa: ok
  domains/launcher/rofi/config/theme.rasi render + kanagawa: ok
  domains/llm/opencode/config/tui.json render + kanagawa: ok
  domains/llm/opencode/config/themes/angst.json render + kanagawa: ok
  domains/shell/nushell/config/colors.nu render + kanagawa: ok
  domains/shell/starship/config/starship.toml render + kanagawa: ok
  domains/sql-client/sqlit/config/settings.json render + kanagawa: ok
  domains/sql-client/sqlit/config/themes/kanagawa.json render + kanagawa: ok
  domains/terminal/ghostty/config/config render + kanagawa: ok
  domains/terminal/ghostty/config/colors.conf render + kanagawa: ok
  domains/terminal/zellij/config/config.kdl render + kanagawa: ok
  domains/terminal/zellij/config/themes/angst.kdl render + kanagawa: ok
  domains/terminal/zellij/config/layouts/default.kdl render + kanagawa: ok
  domains/wm/i3/config/monitors.conf render + kanagawa: ok
  domains/wm/i3/config/config render + kanagawa: ok
  domains/bar/i3status/config/config render + lotus: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + lotus: ok
  domains/files/yazi/config/theme.toml render + lotus: ok
  domains/git/lazygit/config/config.yml render + lotus: ok
  domains/http-client/posting/config/config.yaml render + lotus: ok
  domains/http-client/posting/config/themes/angst.yaml render + lotus: ok
  domains/launcher/rofi/config/config.rasi render + lotus: ok
  domains/launcher/rofi/config/theme.rasi render + lotus: ok
  domains/llm/opencode/config/tui.json render + lotus: ok
  domains/llm/opencode/config/themes/angst.json render + lotus: ok
  domains/shell/nushell/config/colors.nu render + lotus: ok
  domains/shell/starship/config/starship.toml render + lotus: ok
  domains/sql-client/sqlit/config/settings.json render + lotus: ok
  domains/sql-client/sqlit/config/themes/lotus.json render + lotus: ok
  domains/terminal/ghostty/config/config render + lotus: ok
  domains/terminal/ghostty/config/colors.conf render + lotus: ok
  domains/terminal/zellij/config/config.kdl render + lotus: ok
  domains/terminal/zellij/config/themes/angst.kdl render + lotus: ok
  domains/terminal/zellij/config/layouts/default.kdl render + lotus: ok
  domains/wm/i3/config/monitors.conf render + lotus: ok
  domains/wm/i3/config/config render + lotus: ok
  domains/bar/i3status/config/config render + miasma: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + miasma: ok
  domains/files/yazi/config/theme.toml render + miasma: ok
  domains/git/lazygit/config/config.yml render + miasma: ok
  domains/http-client/posting/config/config.yaml render + miasma: ok
  domains/http-client/posting/config/themes/angst.yaml render + miasma: ok
  domains/launcher/rofi/config/config.rasi render + miasma: ok
  domains/launcher/rofi/config/theme.rasi render + miasma: ok
  domains/llm/opencode/config/tui.json render + miasma: ok
  domains/llm/opencode/config/themes/angst.json render + miasma: ok
  domains/shell/nushell/config/colors.nu render + miasma: ok
  domains/shell/starship/config/starship.toml render + miasma: ok
  domains/sql-client/sqlit/config/settings.json render + miasma: ok
  domains/sql-client/sqlit/config/themes/miasma.json render + miasma: ok
  domains/terminal/ghostty/config/config render + miasma: ok
  domains/terminal/ghostty/config/colors.conf render + miasma: ok
  domains/terminal/zellij/config/config.kdl render + miasma: ok
  domains/terminal/zellij/config/themes/angst.kdl render + miasma: ok
  domains/terminal/zellij/config/layouts/default.kdl render + miasma: ok
  domains/wm/i3/config/monitors.conf render + miasma: ok
  domains/wm/i3/config/config render + miasma: ok
  domains/bar/i3status/config/config render + monochrome: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + monochrome: ok
  domains/files/yazi/config/theme.toml render + monochrome: ok
  domains/git/lazygit/config/config.yml render + monochrome: ok
  domains/http-client/posting/config/config.yaml render + monochrome: ok
  domains/http-client/posting/config/themes/angst.yaml render + monochrome: ok
  domains/launcher/rofi/config/config.rasi render + monochrome: ok
  domains/launcher/rofi/config/theme.rasi render + monochrome: ok
  domains/llm/opencode/config/tui.json render + monochrome: ok
  domains/llm/opencode/config/themes/angst.json render + monochrome: ok
  domains/shell/nushell/config/colors.nu render + monochrome: ok
  domains/shell/starship/config/starship.toml render + monochrome: ok
  domains/sql-client/sqlit/config/settings.json render + monochrome: ok
  domains/sql-client/sqlit/config/themes/monochrome.json render + monochrome: ok
  domains/terminal/ghostty/config/config render + monochrome: ok
  domains/terminal/ghostty/config/colors.conf render + monochrome: ok
  domains/terminal/zellij/config/config.kdl render + monochrome: ok
  domains/terminal/zellij/config/themes/angst.kdl render + monochrome: ok
  domains/terminal/zellij/config/layouts/default.kdl render + monochrome: ok
  domains/wm/i3/config/monitors.conf render + monochrome: ok
  domains/wm/i3/config/config render + monochrome: ok
  domains/bar/i3status/config/config render + noctis: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + noctis: ok
  domains/files/yazi/config/theme.toml render + noctis: ok
  domains/git/lazygit/config/config.yml render + noctis: ok
  domains/http-client/posting/config/config.yaml render + noctis: ok
  domains/http-client/posting/config/themes/angst.yaml render + noctis: ok
  domains/launcher/rofi/config/config.rasi render + noctis: ok
  domains/launcher/rofi/config/theme.rasi render + noctis: ok
  domains/llm/opencode/config/tui.json render + noctis: ok
  domains/llm/opencode/config/themes/angst.json render + noctis: ok
  domains/shell/nushell/config/colors.nu render + noctis: ok
  domains/shell/starship/config/starship.toml render + noctis: ok
  domains/sql-client/sqlit/config/settings.json render + noctis: ok
  domains/sql-client/sqlit/config/themes/noctis.json render + noctis: ok
  domains/terminal/ghostty/config/config render + noctis: ok
  domains/terminal/ghostty/config/colors.conf render + noctis: ok
  domains/terminal/zellij/config/config.kdl render + noctis: ok
  domains/terminal/zellij/config/themes/angst.kdl render + noctis: ok
  domains/terminal/zellij/config/layouts/default.kdl render + noctis: ok
  domains/wm/i3/config/monitors.conf render + noctis: ok
  domains/wm/i3/config/config render + noctis: ok
  domains/bar/i3status/config/config render + rose-pine: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + rose-pine: ok
  domains/files/yazi/config/theme.toml render + rose-pine: ok
  domains/git/lazygit/config/config.yml render + rose-pine: ok
  domains/http-client/posting/config/config.yaml render + rose-pine: ok
  domains/http-client/posting/config/themes/angst.yaml render + rose-pine: ok
  domains/launcher/rofi/config/config.rasi render + rose-pine: ok
  domains/launcher/rofi/config/theme.rasi render + rose-pine: ok
  domains/llm/opencode/config/tui.json render + rose-pine: ok
  domains/llm/opencode/config/themes/angst.json render + rose-pine: ok
  domains/shell/nushell/config/colors.nu render + rose-pine: ok
  domains/shell/starship/config/starship.toml render + rose-pine: ok
  domains/sql-client/sqlit/config/settings.json render + rose-pine: ok
  domains/sql-client/sqlit/config/themes/rose-pine.json render + rose-pine: ok
  domains/terminal/ghostty/config/config render + rose-pine: ok
  domains/terminal/ghostty/config/colors.conf render + rose-pine: ok
  domains/terminal/zellij/config/config.kdl render + rose-pine: ok
  domains/terminal/zellij/config/themes/angst.kdl render + rose-pine: ok
  domains/terminal/zellij/config/layouts/default.kdl render + rose-pine: ok
  domains/wm/i3/config/monitors.conf render + rose-pine: ok
  domains/wm/i3/config/config render + rose-pine: ok

All theme checks passed.
```

## 33. Rendered Output Sizes

> Estimated output lines from multi-line string literals in render.nix.

| Domain | Output files | Est. output lines |
|---|---|---|
| git/lazygit | 1 | 324 |
| terminal/zellij | 3 | 322 |
| launcher/rofi | 2 | 105 |
| shell/nushell | 1 | 101 |
| wm/i3 | 2 | 100 |
| terminal/ghostty | 2 | 50 |
| shell/starship | 1 | 46 |
| editor/nvim | 1 | 37 |
| sql-client/sqlit | 2 | 29 |
| http-client/posting | 2 | 24 |
| bar/i3status | 1 | 14 |
| files/yazi | 1 | 14 |
| llm/opencode | 2 | 0 |

## 34. Growth Velocity

> Monthly lines added/removed across .nix, .sh, and .rs files (excludes merges).

| Month | Added | Removed | Net | Commits |
|---|---|---|---|---|
| 2026-06 | 10483 | 4442 | +6041 | 108 |
| 2026-07 | 8386 | 5438 | +2948 | 111 |

> **12-month totals:** +18869 added, −9880 removed, net +8989

## 35. Theme Token Usage Audit

> How many times each schema token is referenced in each render.nix.

> Token lookup uses regex patterns covering `${p.xxx}`, `${t.safe.xxx}`, `${a.xxx}`, and `${t.ansi.xxx}` references.


### Per-domain usage

| Domain | bg·base | bg·variant | sf·base | sf·variant | fg·base | fg·variant | ac·base | ac·variant | dim | ansi·error | ansi·warn | ansi·info | ansi·success |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bar/i3status | — | — | — | — | — | 1 | — | — | — | 1 | 1 | — | 1 |
| editor/nvim | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| files/yazi | 1 | 2 | 1 | 1 | — | 2 | — | 1 | 1 | — | — | — | — |
| git/lazygit | — | — | — | 2 | 3 | 1 | 2 | 2 | — | 1 | — | — | — |
| http-client/posting | 1 | 1 | 1 | — | 1 | 1 | — | 1 | — | 1 | 1 | — | 1 |
| launcher/rofi | — | 1 | — | — | — | 2 | 1 | — | — | — | — | — | — |
| llm/opencode | 3 | 6 | — | 1 | 5 | 11 | 13 | — | 3 | 3 | 1 | 1 | 3 |
| shell/nushell | 1 | — | 3 | 2 | 24 | 11 | 12 | 1 | 16 | — | — | — | — |
| shell/starship | — | — | — | 3 | 3 | 2 | 3 | 1 | 1 | 7 | 1 | — | 2 |
| sql-client/sqlit | 8 | 1 | 3 | — | 4 | 2 | 1 | 3 | — | 3 | 2 | — | 3 |
| terminal/ghostty | 1 | 1 | 2 | 2 | 2 | 5 | 3 | 4 | 4 | — | — | — | — |
| terminal/zellij | 26 | 3 | 4 | 9 | 12 | 7 | 24 | 6 | 2 | 14 | 16 | 14 | 3 |
| wm/i3 | 16 | — | — | — | 4 | 1 | 4 | — | 3 | 3 | 2 | 3 | — |

### Token popularity summary

| Token | Total uses | Used by (domains) |
|---|---|---|
| `palette.ac.base` | 64 | 10 |
| `palette.fg.base` | 59 | 10 |
| `palette.bg.base` | 58 | 9 |
| `palette.fg.variant` | 47 | 13 |
| `ansi.error` | 34 | 9 |
| `palette.dim` | 31 | 8 |
| `ansi.warn` | 25 | 8 |
| `palette.sf.variant` | 21 | 8 |
| `palette.ac.variant` | 20 | 9 |
| `ansi.info` | 19 | 4 |
| `palette.bg.variant` | 16 | 8 |
| `palette.sf.base` | 15 | 7 |
| `ansi.success` | 14 | 7 |

---

*Analysis complete.*
