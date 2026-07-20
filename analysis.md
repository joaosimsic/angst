# angst flake analysis

*Generated: 2026-07-19 21:07*

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
| Files | 132 .nix files, 5107 LOC |
| Rust | 2171 LOC (tools/vm + tools/shell) |
| Scripts | 286 LOC (bash) |
| Docs | 1294 LOC (openwiki) |
| Flake check | ✗        error: Create local/config.nix (see local/config.nix.example) |
## 2. File Size Heatmap (top 30)

| LOC | File | Section |
|---|---|---|
| 423 | domains/terminal/zellij/render.nix | domains |
| 423 | domains/shell/starship/render.nix | domains |
| 341 | domains/git/lazygit/render.nix | domains |
| 218 | themes/default.nix | themes |
| 199 | lib/virtualisation/vm-profile.nix | lib |
| 147 | domains/wm/i3/render.nix | domains |
| 130 | domains/shell/nushell/render.nix | domains |
| 128 | domains/launcher/rofi/render.nix | domains |
| 105 | domains/sql-client/sqlit/render.nix | domains |
| 104 | lib/domains/module.nix | lib |
| 96 | lib/outputs.nix | lib |
| 91 | lib/domains/activation.nix | lib |
| 89 | domains/terminal/ghostty/render.nix | domains |
| 76 | domains/llm/opencode/render.nix | domains |
| 73 | lib/domains/scan.nix | lib |
| 72 | lib/build/mkHost.nix | lib |
| 69 | lib/read-config.nix | lib |
| 65 | lib/domains/domain-config.nix | lib |
| 62 | domains/terminal/zellij/module.nix | domains |
| 57 | lib/checks/desktop.nix | lib |
| 57 | lib/checks/default.nix | lib |
| 53 | lib/devshell.nix | lib |
| 53 | capabilities/graphical.nix | capabilities |
| 51 | lib/nixos/default.nix | lib |
| 50 | lib/checks/shell.nix | lib |
| 47 | lib/treesitter.nix | lib |
| 47 | domains/http-client/posting/render.nix | domains |
| 42 | capabilities/container.nix | capabilities |
| 39 | capabilities/ssh.nix | capabilities |
| 38 | lib/checks/theme/default.nix | lib |
## 3. Directory Size Breakdown

| Directory | .nix files | LOC | Extra |
|---|---|---|---|
| lib/ | 41 | 1619 |  |
| domains/ | 41 | 2324 |  |
| toolchains/ | 23 | 299 |  |
| themes/ | 11 | 449 |  |
| capabilities/ | 9 | 272 |  |
| scripts/ | 0 | 0 |  (+2 .sh files, 286 LOC) |
## 4. Attribute Surface

| Output | Count | Entries |
|---|---|---|
| packages | 0 |  |
| devShells | 0 |  |
| apps | 0 |  |
| checks | 0 |  |
| nixosConfig | 0 |  |
| homeConfig | 0 |  |
## 5. Configuration Matrix

| Dimension | Count | Values |
|---|---|---|
| Hosts | 0 |  |
| Themes | 9 | catppuccin-mocha, github, gotham, kanagawa, lotus, miasma, monochrome, noctis, rose-pine |
| Architectures | 1 | x86_64-linux |
| Domains | 16 | 16 domains in 12 categories |

> **Possible host/theme configurations:** 0 × 9 = 0
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
| 22 | 22 | lib/toolchain.nix |
| 4 | 9 | lib/checks/theme/assertions.nix |
| 2 | 3 | themes/default.nix |
| 2 | 4 | lib/home/themeModule.nix |
| 2 | 4 | lib/home/fonts.nix |
| 2 | 3 | lib/treesitter.nix |
| 1 | 1 | lib/read-config.nix |
| 1 | 1 | lib/profiles.nix |
| 1 | 1 | lib/outputs.nix |
| 1 | 3 | lib/checks/desktop.nix |
| 1 | 3 | lib/checks/shell.nix |
| 1 | 3 | lib/checks/theme/rendered.nix |
| 1 | 3 | lib/checks/theme/semanticDistinct.nix |
| 1 | 3 | lib/checks/theme/override.nix |
| 1 | 3 | lib/checks/password.nix |

### Largest dependency fan-out

| Imports | File |
|---|---|
| 6 | lib/checks/default.nix |
| 6 | lib/outputs.nix |
| 6 | lib/profiles.nix |
| 3 | flake.nix |
| 3 | lib/domains/default.nix |
| 3 | lib/read-config.nix |
| 2 | lib/render.nix |
| 1 | capabilities/graphical.nix |
| 1 | lib/build/mkHome.nix |
| 1 | lib/build/mkHost.nix |
| 1 | lib/checks/theme/default.nix |
| 1 | lib/checks/theme/rendered.nix |
| 1 | lib/checks/theme/semanticDistinct.nix |
| 1 | lib/domains/module.nix |
| 1 | lib/home/font.nix |
## 8. Module Coupling Graph


### Import tree (from flake.nix)

```
flake.nix
├── lib/read-config.nix
│   ├── lib/domains/default.nix
│   │   ├── lib/domains/scan.nix
│   │   ├── lib/domains/activation.nix
│   │   └── lib/domains/module.nix
│   │       └── lib/checks/theme/assertions.nix
│   ├── themes/default.nix
│   │   └── themes/schema.nix
│   └── lib/treesitter.nix
├── lib/profiles.nix
│   ├── lib/mkDomainEnable.nix
│   ├── profiles/base.nix
│   ├── profiles/desktop.nix
│   ├── profiles/development.nix
│   ├── profiles/server.nix
│   └── profiles/vm.nix
└── lib/outputs.nix
    ├── lib/build/mkHome.nix
    │   └── lib/home/themeModule.nix
    ├── lib/build/mkHost.nix
    │   └── lib/home/themeModule.nix
    ├── lib/tools.nix
    ├── lib/render.nix
    │   ├── lib/home/fonts.nix
    │   └── lib/checks/theme/assertions.nix
    ├── lib/devshell.nix
    └── lib/checks/default.nix
        ├── lib/checks/desktop.nix
        ├── lib/checks/shell.nix
        ├── lib/checks/theme/rendered.nix
        │   └── lib/checks/theme/assertions.nix
        ├── lib/checks/theme/semanticDistinct.nix
        │   └── lib/checks/theme/assertions.nix
        ├── lib/checks/theme/override.nix
        └── lib/checks/password.nix
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


**7 violations detected:**

- `capabilities/graphical.nix` → `themes/default.nix`
- `lib/profiles.nix` → `profiles/base.nix`
- `lib/profiles.nix` → `profiles/desktop.nix`
- `lib/profiles.nix` → `profiles/development.nix`
- `lib/profiles.nix` → `profiles/server.nix`
- `lib/profiles.nix` → `profiles/vm.nix`
- `lib/read-config.nix` → `themes/default.nix`

### Module Dependency Graph (Mermaid)

```mermaid
flowchart LR
    n0["flake.nix"] --> n1["lib/read-config.nix"]
    n1["lib/read-config.nix"] --> n2["lib/domains/default.nix"]
    n2["lib/domains/default.nix"] --> n3["lib/domains/scan.nix"]
    n2["lib/domains/default.nix"] --> n4["lib/domains/activation.nix"]
    n2["lib/domains/default.nix"] --> n5["lib/domains/module.nix"]
    n5["lib/domains/module.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n1["lib/read-config.nix"] --> n7["themes/default.nix"]
    n7["themes/default.nix"] --> n8["themes/schema.nix"]
    n1["lib/read-config.nix"] --> n9["lib/treesitter.nix"]
    n0["flake.nix"] --> n10["lib/profiles.nix"]
    n10["lib/profiles.nix"] --> n11["lib/mkDomainEnable.nix"]
    n10["lib/profiles.nix"] --> n12["profiles/base.nix"]
    n10["lib/profiles.nix"] --> n13["profiles/desktop.nix"]
    n10["lib/profiles.nix"] --> n14["profiles/development.nix"]
    n10["lib/profiles.nix"] --> n15["profiles/server.nix"]
    n10["lib/profiles.nix"] --> n16["profiles/vm.nix"]
    n0["flake.nix"] --> n17["lib/outputs.nix"]
    n17["lib/outputs.nix"] --> n18["lib/build/mkHome.nix"]
    n18["lib/build/mkHome.nix"] --> n19["lib/home/themeModule.nix"]
    n17["lib/outputs.nix"] --> n20["lib/build/mkHost.nix"]
    n20["lib/build/mkHost.nix"] --> n19["lib/home/themeModule.nix"]
    n17["lib/outputs.nix"] --> n21["lib/tools.nix"]
    n17["lib/outputs.nix"] --> n22["lib/render.nix"]
    n22["lib/render.nix"] --> n23["lib/home/fonts.nix"]
    n22["lib/render.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n17["lib/outputs.nix"] --> n24["lib/devshell.nix"]
    n17["lib/outputs.nix"] --> n25["lib/checks/default.nix"]
    n25["lib/checks/default.nix"] --> n26["lib/checks/desktop.nix"]
    n25["lib/checks/default.nix"] --> n27["lib/checks/shell.nix"]
    n25["lib/checks/default.nix"] --> n28["lib/checks/theme/rendered.nix"]
    n28["lib/checks/theme/rendered.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n25["lib/checks/default.nix"] --> n29["lib/checks/theme/semanticDistinct.nix"]
    n29["lib/checks/theme/semanticDistinct.nix"] --> n6["lib/checks/theme/assertions.nix"]
    n25["lib/checks/default.nix"] --> n30["lib/checks/theme/override.nix"]
    n25["lib/checks/default.nix"] --> n31["lib/checks/password.nix"]
```
## 9. Build Graph Depth


Maximum dependency depth from **flake.nix**: **4**

Longest import chain:

```
flake.nix
 └─ lib/read-config.nix
     └─ lib/domains/default.nix
         └─ lib/domains/module.nix
             └─ lib/checks/theme/assertions.nix
```
## 10. Duplication Hotspots


### userEnv parsing (parseEnv.nix)

_(none found)_

### "x86_64-linux" hardcoded

- `lib/read-config.nix`

### "proj/angst" hardcoded

_(none found)_

### "allowUnfree" hardcoded

- `flake.nix`
- `lib/read-config.nix`
- `lib/outputs.nix`
- `lib/nixos/default.nix`
- `lib/build/mkHome.nix`
- `lib/build/mkHost.nix`

### Key re-imports (dedup candidates)

- **themes/default**: 2 files import it
  - `capabilities/graphical.nix`
  - `lib/read-config.nix`
## 11. Hardcoded Strings Inventory

| String | Occurrences | Files | Description |
|---|---|---|---|
| "angst" | 60 | 19 | project name |
| "ANGST" | 5 | 3 | env var prefix |
| "nixpkgs" | 14 | 6 | flake input |
| "home-manager" | 13 | 6 | flake input |
| "proj/angst" | 0 | 0 | repo path |
| "x86_64" | 1 | 1 | architecture |
| "allowUnfree" | 6 | 6 | nixpkgs config |
| "generic" | 0 | 0 | default host |
| "monochrome" | 2 | 2 | default theme |
| "NIX_" | 1 | 1 | nix env vars |
| "ANGST_" | 5 | 3 | angst env vars |
## 12. Domain Inventory

| Category | Domains | Names | Render | Module | LOC |
|---|---|---|---|---|---|
| bar | 1 | i3status | 1 | 1 | 46 |
| editor | 1 | nvim | 1 | 1 | 54 |
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

- **22 toolchains**, 284 total LOC

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
  - `just` — 8 LOC
  - `lua` — 12 LOC
  - `markdown` — 14 LOC
  - `nix` — 21 LOC
  - `php` — 26 LOC
  - `python` — 16 LOC
  - `rust` — 13 LOC
  - `terraform` — 9 LOC
  - `toml` — 9 LOC
  - `xml` — 9 LOC
## 16. Host Inventory

(no hosts/)
## 17. Option Inventory

| Construct | Count |
|---|---|
| mkOption | 7 |
| mkEnableOption | 11 |
| mkIf | 31 |

### Option namespace references

| Namespace | References |
|---|---|
| capabilities | 9 |
| angst | 2 |
| domains | 2 |
| theme | 1 |
| domainConfig | 1 |
| font | 1 |
| toolchains | 1 |
## 18. Nix Idiom Usage

| Idiom | Count |
|---|---|
| lib.mkIf | 29 |
| lib.mkForce | 17 |
| lib.mkEnableOption | 11 |
| lib.mkDefault | 11 |
| lib.escapeShellArg | 9 |
| lib.concatMap | 7 |
| lib.mapAttrs | 3 |
| lib.filterAttrs | 3 |
| lib.nameValuePair | 2 |
| lib.listToAttrs | 2 |
| lib.optional | 1 |
| lib.genAttrs | 0 |
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
| mkIf | 31 | 26 |
| mkDefault | 11 | 4 |
| mkForce | 17 | 5 |
| mkOption | 7 | 7 |
| mkEnableOption | 11 | 10 |

### Builtins frequency (top 15)

| Builtin | Count |
|---|---|
| builtins.throw | 12 |
| builtins.pathExists | 9 |
| builtins.attrNames | 6 |
| builtins.readDir | 5 |
| builtins.concatStringsSep | 5 |
| builtins.readFile | 3 |
| builtins.filter | 3 |
| builtins.toJSON | 3 |
| builtins.match | 2 |
| builtins.elem | 2 |
| builtins.head | 2 |
| builtins.dirOf | 1 |
| builtins.removeAttrs | 1 |
| builtins.isString | 1 |
| builtins.isAttrs | 1 |
## 20. Complexity Metrics


### All files with non-trivial complexity

| Score | File | Contributing factors |
|---|---|---|
| 7 | `themes/default.nix` | depth=3, interp=27, LOC=218 |
| 7 | `domains/shell/starship/render.nix` | depth=2, interp=32, LOC=423 |
| 6 | `lib/virtualisation/vm-profile.nix` | interp=12, cond=14, LOC=199 |
| 6 | `lib/domains/module.nix` | depth=4, interp=18, LOC=104 |
| 6 | `domains/terminal/zellij/render.nix` | interp=167, LOC=423 |
| 5 | `lib/domains/activation.nix` | depth=2, interp=31, LOC=91 |
| 5 | `domains/wm/i3/render.nix` | depth=2, interp=43, LOC=147 |
| 4 | `lib/outputs.nix` | interp=31, LOC=96 |
| 4 | `domains/sql-client/sqlit/render.nix` | interp=48, LOC=105 |
| 4 | `domains/shell/nushell/render.nix` | interp=72, LOC=130 |
| 4 | `domains/git/lazygit/render.nix` | interp=11, LOC=341 |
| 3 | `domains/terminal/ghostty/render.nix` | interp=28, LOC=89 |
| 3 | `domains/llm/opencode/render.nix` | interp=50 |
| 2 | `lib/nixos/default.nix` | cond=7 |
| 2 | `lib/domains/scan.nix` | depth=2, interp=9 |
| 2 | `lib/domains/domain-config.nix` | depth=2, interp=15 |
| 1 | `lib/virtualisation/runtime.nix` | cond=4 |
| 1 | `lib/virtualisation/host-mount.nix` | interp=9 |
| 1 | `lib/treesitter.nix` | interp=15 |
| 1 | `lib/read-config.nix` | depth=2 |
| 1 | `lib/profiles.nix` | depth=2 |
| 1 | `lib/mkDomainEnable.nix` | interp=6 |
| 1 | `lib/devshell.nix` | interp=12 |
| 1 | `lib/checks/theme/assertions.nix` | depth=2 |
| 1 | `lib/checks/desktop.nix` | interp=6 |
| 1 | `lib/build/mkHost.nix` | depth=2 |
| 1 | `domains/wm/i3/module.nix` | interp=6 |
| 1 | `domains/launcher/rofi/render.nix` | LOC=128 |
| 1 | `domains/http-client/posting/render.nix` | interp=10 |
| 1 | `domains/files/yazi/render.nix` | interp=9 |
| 1 | `domains/editor/nvim/render.nix` | interp=13 |
## 21. "Interesting" Complexity Metrics


### Deepest Attrset Nesting

| Value | File |
|---|---|
| 7 | `domains/terminal/zellij/render.nix` |
| 6 | `lib/virtualisation/vm-profile.nix` |
| 6 | `capabilities/graphical.nix` |
| 5 | `lib/virtualisation/vm-variant.nix` |
| 5 | `lib/outputs.nix` |
| 5 | `domains/terminal/zellij/module.nix` |
| 4 | `themes/default.nix` |
| 4 | `lib/read-config.nix` |

### Most Rec Blocks

| Value | File |
|---|---|
| 1 | `lib/render.nix` |
| 1 | `lib/outputs.nix` |

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
| 41 | `themes/default.nix` |
| 30 | `lib/outputs.nix` |
| 18 | `lib/checks/default.nix` |
| 17 | `lib/read-config.nix` |
| 14 | `themes/miasma.nix` |

### Largest List

| Value | File |
|---|---|
| 379 | `domains/shell/starship/render.nix` |
| 203 | `domains/git/lazygit/render.nix` |
| 200 | `themes/default.nix` |
| 144 | `lib/virtualisation/vm-profile.nix` |
| 113 | `domains/launcher/rofi/render.nix` |
| 110 | `domains/wm/i3/render.nix` |
| 82 | `domains/sql-client/sqlit/render.nix` |
| 75 | `domains/terminal/zellij/render.nix` |

### Longest String (Lines)

| Value | File |
|---|---|
| 326 | `domains/git/lazygit/render.nix` |
| 145 | `domains/terminal/zellij/render.nix` |
| 103 | `domains/shell/nushell/render.nix` |
| 102 | `domains/wm/i3/render.nix` |
| 97 | `domains/launcher/rofi/render.nix` |
| 48 | `domains/shell/starship/render.nix` |
| 39 | `domains/terminal/zellij/module.nix` |
| 31 | `domains/terminal/ghostty/render.nix` |

### Deepest Function Pipeline (|>)

| Value | File |
|---|---|
## 22. Error Handling

| Construct | Count |
|---|---|
| throw | 15 |
| abort | 0 |
| assert | 0 |

### Throw locations

- `lib/mkDomainEnable.nix:9:  builtins.throw "Unknown domain '${name}'. Available: ${builtins.concatStringsSep ", " (map (e: "${e.category}.${e.name}") entries)}"`
- `lib/read-config.nix:8:               else builtins.throw "Create local/config.nix (see local/config.nix.example)";`
- `lib/read-config.nix:65:             then builtins.throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " bareNames}"`
- `lib/read-config.nix:67:         else builtins.throw "toolchains must be \"*\" or a list";`
- `themes/default.nix:131:      builtins.throw "Theme '${name}' missing tokens: ${`
- `themes/default.nix:135:      builtins.throw "Theme '${name}' has invalid hex for: ${`
- `themes/default.nix:215:      builtins.throw "Unknown theme '${name}'. Available themes: ${`
- `lib/render.nix:24:    in if matches == [] then builtins.throw "Unknown domain render output: ${outputPath}"`
- `lib/domains/scan.nix:18:      builtins.throw "domains/${category}/${name}/meta.nix: 'xdg' and 'xdgFile' are mutually exclusive"`
- `lib/domains/scan.nix:20:      builtins.throw "domains/${category}/${name}/meta.nix: must set 'xdg', 'xdgFile', or 'customXdg = true'"`
- `lib/checks/theme/override.nix:20:  throw "expected config.theme = ${overrideTheme}, got ${theme}"`
- `lib/checks/theme/override.nix:22:  throw "theme override did not reach rendered ghostty colors (expected ${overrideTheme} background.variant)"`
## 23. Dead Code

> `deadnix` not found. Install with `nix shell nixpkgs#deadnix`.

## 24. Anti-Patterns (statix)

> `statix` not found. Install with `nix shell nixpkgs#statix`.

## 25. Evaluation Cost


### Evaluation (attribute resolution)

| Command | Result | Time |
|---|---|---|
| nix flake show | ✗ | 0.04s |
| packages.x86_64-linux | ✗ | 0.04s |
| apps.x86_64-linux | ✗ | 0.04s |
| checks.x86_64-linux | ✗ | 0.04s |

### Build (realisation)

| Command | Result | Time |
|---|---|---|
| nix flake check | ✗ | 0.04s |
## 26. Technical Debt Score


### Architecture

- ✓ No cyclic imports
- ✓ parseEnv imported from 0 files

### Portability

- ✓ 1 architecture-specific literals (x86_64-linux)
- ✓ 0 repository path literals (proj/angst)
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
| `domains/git/lazygit/render.nix` | 341 | 2 | 0 | 0 | Medium | 4 |
| `themes/default.nix` | 218 | 12 | 1 | 2 | Very High | 7 |
| `lib/virtualisation/vm-profile.nix` | 199 | 7 | 0 | 0 | High | 6 |
| `domains/wm/i3/render.nix` | 147 | 3 | 0 | 0 | High | 5 |
| `domains/shell/nushell/render.nix` | 130 | 6 | 0 | 0 | Very High | 7 |
| `domains/launcher/rofi/render.nix` | 128 | 3 | 0 | 0 | Low | 1 |
| `domains/sql-client/sqlit/render.nix` | 105 | 7 | 0 | 0 | Medium | 4 |
| `lib/domains/module.nix` | 104 | 11 | 1 | 1 | High | 6 |
| `lib/outputs.nix` | 96 | 3 | 6 | 1 | Medium | 4 |
| `lib/domains/activation.nix` | 91 | 10 | 0 | 1 | High | 5 |
| `domains/terminal/ghostty/render.nix` | 89 | 6 | 0 | 0 | Medium | 3 |
| `domains/llm/opencode/render.nix` | 76 | 4 | 0 | 0 | Medium | 3 |
| `lib/domains/scan.nix` | 73 | 3 | 0 | 1 | Low | 2 |
| `lib/build/mkHost.nix` | 72 | 15 | 1 | 1 | Low | 1 |
| `lib/read-config.nix` | 69 | 3 | 3 | 1 | Low | 1 |
| `lib/domains/domain-config.nix` | 65 | 8 | 0 | 0 | Low | 2 |
| `domains/terminal/zellij/module.nix` | 62 | 3 | 0 | 0 | Minimal | 0 |
| `lib/checks/desktop.nix` | 57 | 7 | 0 | 1 | Low | 1 |
| `lib/checks/default.nix` | 57 | 2 | 6 | 1 | Minimal | 0 |
| `capabilities/graphical.nix` | 53 | 5 | 1 | 0 | Minimal | 0 |
| `lib/devshell.nix` | 53 | 1 | 0 | 1 | Low | 1 |
| `lib/nixos/default.nix` | 51 | 8 | 0 | 0 | Low | 2 |
| `lib/checks/shell.nix` | 50 | 4 | 0 | 1 | Low | 1 |
## 28. Stability Index

> Cross-references git churn with file recency. **Hot** = high churn + recently modified, **Active** = moderate churn, **Stable** = low churn, **Archived** = no changes in 6+ months.

| File | Churn | Last changed | Label |
|---|---|---|---|
| `flake.nix` | 30 | 2026-07-17 | Hot |
| `lib/build/mkHome.nix` | 22 | 2026-07-19 | Hot |
| `domains/terminal/zellij/render.nix` | 20 | 2026-07-15 | Hot |
| `lib/build/mkHost.nix` | 15 | 2026-07-19 | Hot |
| `domains/shell/starship/render.nix` | 14 | 2026-07-16 | Hot |
| `themes/miasma.nix` | 13 | 2026-07-16 | Hot |
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
| `lib/checks/theme/rendered.nix` | 9 | 2026-07-12 | Active |
| `toolchains/javascript.nix` | 9 | 2026-07-14 | Active |
| `themes/schema.nix` | 8 | 2026-07-10 | Active |
| `lib/domains/domain-config.nix` | 8 | 2026-07-17 | Active |
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
| `catppuccin-mocha` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `github` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `gotham` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `kanagawa` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `lotus` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `miasma` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `monochrome` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `noctis` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
| `rose-pine` |  |  |  |  |  |  | — |  | — |  |  |  |  | — |  |  |
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

_(no checks found)_
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
| sql-client/sqlit | 2 | 29 |
| http-client/posting | 2 | 24 |
| editor/nvim | 1 | 16 |
| bar/i3status | 1 | 14 |
| files/yazi | 1 | 14 |
| llm/opencode | 2 | 0 |
## 34. Growth Velocity

> Monthly lines added/removed across .nix, .sh, and .rs files (excludes merges).

| Month | Added | Removed | Net | Commits |
|---|---|---|---|---|
| 2026-06 | 10478 | 4437 | +6041 | 108 |
| 2026-07 | 9079 | 7227 | +1852 | 119 |

> **12-month totals:** +19557 added, −11664 removed, net +7893
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
