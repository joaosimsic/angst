# angst flake analysis

*Generated: 2026-08-26 16:05*

## Table of Contents

- [1. Overview](#overview)
- [2. File Size Heatmap (top 30)](#file-size-heatmap-top-30)
- [3. Directory Size Breakdown](#directory-size-breakdown)
- [4. Attribute Surface](#attribute-surface)
- [5. Configuration Matrix](#configuration-matrix)
- [6. Domain Feature Coverage](#domain-feature-coverage)
- [7. Dependency Fan-in / Fan-out](#dependency-fan-in-fan-out)
- [8. Module Coupling Graph](#module-coupling-graph)
- [9. Build Graph Depth](#build-graph-depth)
- [10. Duplication Hotspots](#duplication-hotspots)
- [11. Hardcoded Strings Inventory](#hardcoded-strings-inventory)
- [12. Domain Inventory](#domain-inventory)
- [13. Theme Inventory](#theme-inventory)
- [14. System Feature Inventory](#system-feature-inventory)
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
- [29. Theme × Domain Coverage](#theme-domain-coverage)
- [30. Domain Features](#domain-features)
- [31. Check Results Breakdown](#check-results-breakdown)
- [32. Rendered Output Sizes](#rendered-output-sizes)
- [33. Growth Velocity](#growth-velocity)
- [34. Theme Token Usage Audit](#theme-token-usage-audit)
- [35. Eval Memory (peak RSS)](#eval-memory-peak-rss)


## 1. Overview

| Metric | Value |
|---|---|
| Files | 216 .nix files, 9402 LOC |
| Rust | 0 LOC |
| Scripts | 0 LOC (bash) |
| Docs | 840 LOC (openwiki) |
| Flake check | ✗ checking derivation checks.x86_64-linux.login-shell-invalid... |
## 2. File Size Heatmap (top 30)

| LOC | File | Section |
|---|---|---|
| 341 | domains/git/lazygit/render.nix | domains |
| 268 | domains/shell/starship/modules.nix | domains |
| 264 | themes/default.nix | themes |
| 258 | domains/terminal/zellij/render.nix | domains |
| 250 | checks/vault-pipeline.nix | checks |
| 243 | runtime/default.nix | runtime |
| 236 | lib/domains/module.nix | lib |
| 212 | lib/flake/context.nix | lib |
| 191 | domains/shell/nushell/render.nix | domains |
| 187 | checks/secrets.nix | checks |
| 185 | lib/build/mkNixos.nix | lib |
| 182 | modules/vm/vm-profile.nix | modules |
| 177 | domains/sql-client/sqlit/render.nix | domains |
| 162 | domains/shell/starship/render.nix | domains |
| 159 | lib/domains/mkDomain.nix | lib |
| 155 | checks/projects-pipeline.nix | checks |
| 151 | domains/terminal/zellij/theme.nix | domains |
| 148 | checks/default.nix | checks |
| 146 | domains/wm/i3/render.nix | domains |
| 129 | lib/resolve.nix | lib |
| 128 | domains/launcher/rofi/render.nix | domains |
| 121 | checks/ftp-pipeline.nix | checks |
| 107 | checks/secret-scan.nix | checks |
| 99 | domains/remote/ssh/ssh-config.nix | domains |
| 98 | domains/remote/ftp/home.nix | domains |
| 97 | hosts/personal/nixos/default.nix | hosts |
| 93 | checks/declared.nix | checks |
| 89 | domains/terminal/ghostty/render.nix | domains |
| 88 | lib/build/mkHome.nix | lib |
| 84 | checks/secret-scan-hooks.nix | checks |
## 3. Directory Size Breakdown

| Directory | .nix files | LOC | Extra |
|---|---|---|---|
| lib/ | 18 | 1511 |  |
| domains/ | 88 | 3701 |  |
| toolchains/ | 27 | 372 |  |
| themes/ | 11 | 542 |  |
| hosts/ | 5 | 298 |  |
| runtime/ | 24 | 676 |  |
## 4. Attribute Surface

| Output | Count | Entries |
|---|---|---|
| packages | 12 | analyze, angst, angst-shell, ci, default, hm-switch, home, mint... |
| devShells | 3 | dev, safe, vm |
| apps | 13 | analyze, analyze-to-file, angst, check, hm-switch, lint-desktop, lint-shell, lint-themes... |
| checks | 23 | build-all, check-ftp-encrypted, check-ftp-pipeline, check-password, check-projects-encrypted, check-projects-ftp-declared, check-projects-pipeline, check-secrets-encrypted... |
| nixosConfig | 3 | ci, nixos, vm |
| homeConfig | 9 | ci, home, login-shell-invalid, login-shell-valid, mint, nixos, runner, runner-theme-override-test... |
## 5. Configuration Matrix

| Dimension | Count | Values |
|---|---|---|
| Hosts | 5 | ci, personal/mint, personal/nixos, vm, work/home |
| Themes | 9 | catppuccin-mocha, github, gotham, kanagawa, lotus, miasma, monochrome, noctis, rose-pine |
| Architectures | 1 | x86_64-linux |
| Domains | 32 | 32 domains in 17 categories |

> **Possible host/theme configurations:** 5 × 9 = 45
## 6. Domain Feature Coverage

| Feature | Count | Coverage |
|---|---|---|
| render.nix | 16 | 50% |
| system.nix | 12 | 37% |
| domain checks | 0 | 0% |
| **total domains** | 32 | 100% |
## 7. Dependency Fan-in / Fan-out


### Most imported modules (fan-in)

| Direct | Transitive | File |
|---|---|---|
| 27 | 27 | lib/toolchain.nix |
| 5 | 7 | lib/nixpkgs-config.nix |
| 4 | 9 | checks/theme/assertions.nix |
| 2 | 3 | lib/treesitter.nix |
| 2 | 5 | modules/home/themeModule.nix |
| 2 | 5 | modules/secrets.nix |
| 1 | 1 | runtime/apps/analyze-to-file.nix |
| 1 | 2 | lib/domains/scan.nix |
| 1 | 4 | checks/theme/override.nix |
| 1 | 1 | checks/theme/entries.nix |
| 1 | 3 | lib/build/mkNixos.nix |
| 1 | 1 | runtime/vm/nixos-switch.nix |
| 1 | 3 | profiles/default.nix |
| 1 | 1 | runtime/angst-cli.nix |
| 1 | 1 | runtime/vm/home-switch.nix |

### Largest dependency fan-out

| Imports | File |
|---|---|
| 23 | runtime/default.nix |
| 15 | checks/default.nix |
| 7 | lib/flake/context.nix |
| 6 | profiles/default.nix |
| 5 | lib/flake/outputs.nix |
| 4 | flake.nix |
| 4 | lib/build/mkNixos.nix |
| 4 | lib/resolve.nix |
| 3 | lib/build/mkHome.nix |
| 2 | domains/terminal/zellij/render.nix |
| 1 | lib/domains/module.nix |
| 1 | toolchains/docker.nix |
| 1 | themes/default.nix |
| 1 | toolchains/php.nix |
| 1 | toolchains/just.nix |
## 8. Module Coupling Graph


### Import tree (from flake.nix)

```
flake.nix
├── themes/default.nix
│   └── themes/schema.nix
├── lib/resolve.nix
│   ├── lib/nixpkgs-config.nix
│   ├── lib/domains/scan.nix
│   │   └── lib/domains/mkDomain.nix
│   ├── lib/domains/module.nix
│   │   └── checks/theme/assertions.nix
│   └── lib/treesitter.nix
├── lib/discover.nix
└── lib/flake/outputs.nix
    ├── lib/flake/context.nix
    │   ├── lib/nixpkgs-config.nix
    │   ├── profiles/default.nix
    │   │   ├── profiles/base.nix
    │   │   ├── profiles/desktop.nix
    │   │   ├── profiles/development.nix
    │   │   ├── profiles/embedded.nix
    │   │   ├── profiles/server.nix
    │   │   └── profiles/vm.nix
    │   ├── lib/build/mkHome.nix
    │   │   ├── lib/nixpkgs-config.nix
    │   │   ├── modules/home/themeModule.nix
    │   │   └── modules/secrets.nix
    │   │       └── modules/home/app-secrets.nix
    │   ├── lib/build/mkNixos.nix
    │   │   ├── lib/nixpkgs-config.nix
    │   │   ├── modules/home/themeModule.nix
    │   │   ├── modules/secrets.nix
    │   │   │   └── modules/home/app-secrets.nix
    │   │   └── modules/nixos/persist.nix
    │   ├── lib/render.nix
    │   │   └── checks/theme/assertions.nix
    │   ├── lib/flake/devshell.nix
    │   └── checks/default.nix
    │       ├── checks/desktop.nix
    │       ├── checks/shell.nix
    │       ├── checks/theme/rendered.nix
    │       │   └── checks/theme/assertions.nix
    │       ├── checks/theme/semanticDistinct.nix
    │       │   └── checks/theme/assertions.nix
    │       ├── checks/theme/override.nix
    │       ├── checks/password.nix
    │       ├── checks/login-shell.nix
    │       ├── checks/lint-nix.nix
    │       ├── checks/secrets.nix
    │       ├── checks/declared.nix
    │       ├── checks/projects-pipeline.nix
    │       ├── checks/vault-pipeline.nix
    │       ├── checks/ftp-pipeline.nix
    │       ├── checks/secret-scan.nix
    │       └── checks/secret-scan-hooks.nix
    ├── lib/flake/configurations.nix
    ├── lib/flake/packages.nix
    ├── lib/flake/apps.nix
    └── lib/flake/checks.nix
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
domains
 ↓
themes
 ↓
toolchains
 ↓
hosts
 ↓
runtime
```


**9 violations detected:**

- `lib/flake/context.nix` → `profiles/default.nix`
- `lib/flake/context.nix` → `checks/default.nix`
- `lib/domains/module.nix` → `checks/theme/assertions.nix`
- `lib/build/mkNixos.nix` → `modules/home/themeModule.nix`
- `lib/build/mkNixos.nix` → `modules/secrets.nix`
- `lib/build/mkNixos.nix` → `modules/nixos/persist.nix`
- `lib/build/mkHome.nix` → `modules/home/themeModule.nix`
- `lib/build/mkHome.nix` → `modules/secrets.nix`
- `lib/render.nix` → `checks/theme/assertions.nix`
## 9. Build Graph Depth


Maximum dependency depth from **flake.nix**: **5**

Longest import chain:

```
flake.nix
 └─ lib/flake/outputs.nix
     └─ lib/flake/context.nix
         └─ lib/build/mkHome.nix
             └─ modules/secrets.nix
                 └─ modules/home/app-secrets.nix
```
## 10. Duplication Hotspots


### userEnv parsing (parseEnv.nix)

_(none found)_

### "x86_64-linux" hardcoded

- `hosts/ci/default.nix`
- `hosts/personal/mint/default.nix`
- `hosts/personal/nixos/default.nix`
- `hosts/vm/default.nix`
- `hosts/work/home/default.nix`
- `lib/flake/context.nix`
- `lib/resolve.nix`

### "proj/angst" hardcoded

_(none found)_

### "allowUnfree" hardcoded

- `lib/nixpkgs-config.nix`

### Key re-imports (dedup candidates)

## 11. Hardcoded Strings Inventory

| String | Occurrences | Files | Description |
|---|---|---|---|
| "angst" | 168 | 51 | project name |
| "ANGST" | 14 | 7 | env var prefix |
| "nixpkgs" | 17 | 6 | flake input |
| "home-manager" | 19 | 11 | flake input |
| "proj/angst" | 0 | 0 | repo path |
| "x86_64" | 7 | 7 | architecture |
| "allowUnfree" | 1 | 1 | nixpkgs config |
| "generic" | 0 | 0 | default host |
| "monochrome" | 3 | 3 | default theme |
| "NIX_" | 2 | 2 | nix env vars |
| "ANGST_" | 14 | 7 | angst env vars |
## 12. Domain Inventory

| Category | Domains | Names | LOC |
|---|---|---|---|
| agents | 2 | cursor-cli,opencode | 155 |
| bar | 1 | i3status | 49 |
| editor | 1 | nvim | 66 |
| embedded | 1 | arduino | 96 |
| files | 1 | yazi | 49 |
| git | 2 | lazygit,projects | 410 |
| http-client | 1 | posting | 66 |
| launcher | 1 | rofi | 150 |
| nix | 1 | nh | 5 |
| remote | 2 | ftp,ssh | 426 |
| security | 1 | age | 5 |
| session | 1 | x11 | 57 |
| shell | 3 | carapace,nushell,starship | 713 |
| sql-client | 2 | rainfrog,sqlit | 286 |
| system | 8 | audio,clipboard,container,git,graphical,monitoring,network,search | 257 |
| terminal | 3 | ghostty,tmux,zellij | 734 |
| wm | 1 | i3 | 177 |
## 13. Theme Inventory

> **See `nix flake show` for the full list.**

- **9 themes**, 259 total LOC

  - `catppuccin-mocha` — 28 LOC
  - `github` — 29 LOC
  - `gotham` — 29 LOC
  - `kanagawa` — 28 LOC
  - `lotus` — 29 LOC
  - `miasma` — 31 LOC
  - `monochrome` — 28 LOC (default)
  - `noctis` — 28 LOC
  - `rose-pine` — 29 LOC
## 14. System Feature Inventory

> **See `nix flake show` for the full list.**

- **8 system features**, 241 total LOC

  - `system/audio` — 29 LOC
  - `system/clipboard` — 23 LOC
  - `system/container` — 43 LOC
  - `system/git` — 22 LOC
  - `system/graphical` — 54 LOC
  - `system/monitoring` — 22 LOC
  - `system/network` — 24 LOC
  - `system/search` — 24 LOC
## 15. Toolchain Inventory

> **See `nix flake show` for the full list.**

- **27 toolchains**, 372 total LOC

  - `bash` — 12 LOC
  - `blade` — 15 LOC
  - `c` — 14 LOC
  - `clojure` — 14 LOC
  - `conf` — 9 LOC
  - `css` — 9 LOC
  - `docker` — 13 LOC
  - `editorconfig` — 10 LOC
  - `go` — 18 LOC
  - `haskell` — 14 LOC
  - `html` — 9 LOC
  - `java` — 14 LOC
  - `javascript` — 26 LOC
  - `json` — 11 LOC
  - `just` — 12 LOC
  - `lua` — 13 LOC
  - `make` — 10 LOC
  - `markdown` — 15 LOC
  - `nix` — 22 LOC
  - `odin` — 11 LOC
  - `php` — 27 LOC
  - `python` — 17 LOC
  - `rust` — 14 LOC
  - `terraform` — 10 LOC
  - `toml` — 10 LOC
  - `xml` — 10 LOC
  - `yaml` — 13 LOC
## 16. Host Inventory


- **ci/**
  - `default.nix` — 10 LOC

- **personal/mint/**
  - `default.nix` — 72 LOC

- **personal/nixos/**
  - `default.nix` — 97 LOC

- **vm/**
  - `default.nix` — 78 LOC

- **work/home/**
  - `default.nix` — 41 LOC
## 17. Option Inventory

| Construct | Count |
|---|---|
| mkOption | 24 |
| mkEnableOption | 13 |
| mkIf | 50 |

### Option namespace references

| Namespace | References |
|---|---|
| angst | 8 |
| domains | 13 |
| font | 1 |
| theme | 1 |
| toolchains | 1 |
## 18. Nix Idiom Usage

| Idiom | Count |
|---|---|
| lib.mkIf | 48 |
| lib.types | 34 |
| lib.mkOption | 24 |
| lib.mkForce | 20 |
| lib.escapeShellArg | 16 |
| lib.concatMap | 10 |
| lib.filterAttrs | 5 |
| lib.nameValuePair | 4 |
| lib.optional | 3 |
| lib.mapAttrs | 3 |
| lib.listToAttrs | 3 |
| lib.mkMerge | 1 |
| lib.flatten | 1 |
| lib.optionalAttrs | 1 |
| lib.zipAttrsWith | 0 |
| lib.foldl' | 0 |
| lib.pipe | 0 |
| lib.genAttrs | 0 |
## 19. Conditional & Builtins Usage


### Conditional logic

| Construct | Count | Files |
|---|---|---|
| mkIf | 50 | 42 |
| mkDefault | 11 | 3 |
| mkForce | 20 | 5 |
| mkOption | 24 | 12 |
| mkEnableOption | 13 | 13 |

### Builtins frequency (top 15)

| Builtin | Count |
|---|---|
| builtins.concatStringsSep | 15 |
| builtins.pathExists | 11 |
| builtins.attrNames | 11 |
| builtins.readDir | 9 |
| builtins.filter | 9 |
| builtins.isString | 6 |
| builtins.elem | 6 |
| builtins.throw | 6 |
| builtins.attrValues | 5 |
| builtins.mapAttrs | 5 |
| builtins.listToAttrs | 4 |
| builtins.removeAttrs | 4 |
| builtins.head | 4 |
| builtins.toJSON | 3 |
| builtins.hasAttr | 3 |
## 20. Complexity Metrics


### All files with non-trivial complexity

| Score | File | Contributing factors |
|---|---|---|
| 9 | `lib/domains/module.nix` | depth=3, interp=39, cond=5, LOC=236 |
| 9 | `modules/vm/vm-profile.nix` | depth=3, interp=7, cond=15, LOC=182 |
| 7 | `themes/default.nix` | depth=3, interp=27, LOC=264 |
| 6 | `domains/sql-client/sqlit/render.nix` | depth=2, interp=54, LOC=177 |
| 6 | `domains/shell/starship/render.nix` | depth=2, interp=31, LOC=162 |
| 5 | `lib/domains/mkDomain.nix` | depth=2, interp=18, LOC=159 |
| 5 | `lib/build/mkNixos.nix` | depth=2, interp=9, cond=3, LOC=185 |
| 5 | `domains/wm/i3/render.nix` | depth=2, interp=43, LOC=146 |
| 5 | `domains/terminal/zellij/theme.nix` | interp=94, LOC=151 |
| 5 | `domains/terminal/zellij/render.nix` | interp=49, LOC=258 |
| 5 | `domains/shell/nushell/render.nix` | interp=73, LOC=191 |
| 5 | `runtime/default.nix` | depth=2, interp=18, LOC=243 |
| 4 | `domains/git/lazygit/render.nix` | interp=11, LOC=341 |
| 4 | `domains/agents/opencode/render.nix` | interp=50, LOC=81 |
| 3 | `lib/flake/context.nix` | depth=2, LOC=212 |
| 3 | `domains/sql-client/rainfrog/render.nix` | depth=2, interp=16 |
| 3 | `domains/terminal/ghostty/render.nix` | interp=28, LOC=89 |
| 3 | `domains/remote/ftp/home.nix` | depth=2, interp=9, LOC=98 |
| 2 | `lib/resolve.nix` | depth=2, LOC=129 |
| 2 | `checks/secret-scan.nix` | interp=6, LOC=107 |
| 2 | `checks/default.nix` | depth=2, LOC=148 |
| 2 | `domains/remote/ssh/ssh-config.nix` | interp=14, LOC=99 |
| 2 | `domains/shell/starship/modules.nix` | LOC=268 |
| 2 | `profiles/default.nix` | depth=2, interp=10 |
| 2 | `modules/vm/host-mount.nix` | interp=18 |
| 2 | `modules/nixos/default.nix` | cond=7 |
| 2 | `checks/declared.nix` | interp=10, LOC=93 |
| 2 | `domains/terminal/tmux/render.nix` | interp=21 |
| 2 | `domains/terminal/zellij/layout.nix` | interp=24 |
| 2 | `checks/vault-pipeline.nix` | LOC=250 |
| 2 | `lib/domains/scan.nix` | depth=2, interp=7 |
| 2 | `checks/secrets.nix` | LOC=187 |
| 2 | `checks/projects-pipeline.nix` | LOC=155 |
| 2 | `lib/discover.nix` | depth=2, interp=8 |
| 1 | `checks/secret-scan-hooks.nix` | LOC=84 |
| 1 | `modules/home/app-secrets.nix` | interp=6 |
| 1 | `hosts/personal/nixos/default.nix` | LOC=97 |
| 1 | `domains/session/x11/render.nix` | interp=6 |
| 1 | `flake.nix` | depth=2 |
| 1 | `checks/theme/assertions.nix` | depth=2 |
| 1 | `lib/flake/apps.nix` | interp=15 |
| 1 | `checks/login-shell.nix` | depth=2 |
| 1 | `lib/flake/devshell.nix` | interp=7 |
| 1 | `domains/editor/nvim/render.nix` | interp=13 |
| 1 | `lib/treesitter.nix` | interp=10 |
| 1 | `lib/build/mkHome.nix` | LOC=88 |
| 1 | `modules/home/login-shell.nix` | interp=8 |
| 1 | `domains/files/yazi/render.nix` | interp=9 |
| 1 | `domains/http-client/posting/render.nix` | interp=10 |
| 1 | `modules/vm/runtime.nix` | cond=4 |
| 1 | `checks/ftp-pipeline.nix` | LOC=121 |
| 1 | `domains/launcher/rofi/render.nix` | LOC=128 |
| 1 | `checks/desktop.nix` | interp=6 |
| 1 | `runtime/ftp-mount.nix` | interp=6 |
| 1 | `runtime/vm/ephemeral-ssh.nix` | interp=6 |
| 1 | `domains/shell/nushell/healthcheck.nix` | interp=13 |
## 21. "Interesting" Complexity Metrics


### Deepest Attrset Nesting

| Value | File |
|---|---|
| 7 | `modules/vm/vm-profile.nix` |
| 7 | `domains/remote/ssh/ssh-config.nix` |
| 7 | `domains/terminal/zellij/render.nix` |
| 6 | `lib/build/mkNixos.nix` |
| 6 | `domains/remote/ftp/home.nix` |
| 6 | `domains/remote/ssh/ssh-agent.nix` |
| 6 | `domains/remote/ssh/system.nix` |
| 6 | `domains/system/graphical/system.nix` |

### Most Rec Blocks

| Value | File |
|---|---|
| 1 | `lib/render.nix` |

### Most With Blocks

| Value | File |
|---|---|
| 6 | `toolchains/rust.nix` |
| 6 | `toolchains/java.nix` |
| 6 | `toolchains/python.nix` |
| 6 | `toolchains/clojure.nix` |
| 6 | `toolchains/go.nix` |
| 6 | `toolchains/haskell.nix` |
| 5 | `toolchains/nix.nix` |
| 5 | `toolchains/php.nix` |

### Deepest MkIf Nesting

| Value | File |
|---|---|
| 3 | `lib/domains/module.nix` |
| 3 | `modules/vm/runtime.nix` |
| 2 | `domains/remote/ssh/system.nix` |
| 2 | `domains/terminal/zellij/home.nix` |
| 1 | `domains/terminal/tmux/home.nix` |
| 1 | `domains/agents/opencode/home.nix` |
| 1 | `modules/home/login-shell.nix` |
| 1 | `lib/build/mkNixos.nix` |

### Largest Attrset

| Value | File |
|---|---|
| 157 | `domains/shell/starship/modules.nix` |
| 58 | `domains/agents/opencode/render.nix` |
| 54 | `modules/vm/vm-profile.nix` |
| 45 | `themes/default.nix` |
| 39 | `runtime/default.nix` |
| 36 | `lib/domains/mkDomain.nix` |
| 34 | `hosts/personal/nixos/default.nix` |
| 33 | `lib/flake/context.nix` |

### Largest List

| Value | File |
|---|---|
| 261 | `domains/shell/starship/modules.nix` |
| 116 | `domains/git/lazygit/render.nix` |
| 101 | `domains/launcher/rofi/render.nix` |
| 90 | `domains/wm/i3/render.nix` |
| 67 | `domains/sql-client/sqlit/render.nix` |
| 56 | `lib/domains/mkDomain.nix` |
| 55 | `domains/shell/starship/render.nix` |
| 53 | `domains/terminal/zellij/render.nix` |

### Longest String (lines)

| Value | File |
|---|---|
| 325 | `domains/git/lazygit/render.nix` |
| 220 | `checks/vault-pipeline.nix` |
| 145 | `domains/terminal/zellij/theme.nix` |
| 140 | `domains/terminal/zellij/render.nix` |
| 128 | `checks/projects-pipeline.nix` |
| 103 | `domains/shell/nushell/render.nix` |
| 101 | `domains/wm/i3/render.nix` |
| 97 | `domains/launcher/rofi/render.nix` |

### Deepest Function Pipeline (|>)

| Value | File |
|---|---|
## 22. Error Handling

| Construct | Count |
|---|---|
| throw | 21 |
| abort | 0 |
| assert | 0 |

### Throw locations

- `themes/default.nix`
- `profiles/default.nix`
- `checks/theme/context.nix`
- `checks/theme/override.nix`
- `checks/login-shell.nix`
- `lib/resolve.nix`
- `lib/render.nix`
- `lib/domains/module.nix`
- `lib/domains/scan.nix`
- `lib/domains/mkDomain.nix`
- `domains/sql-client/sqlit/render.nix`
- `domains/sql-client/rainfrog/render.nix`
## 23. Dead Code

✓ No dead code detected.
## 24. Anti-Patterns (statix)

✓ No anti-patterns detected.
## 25. Evaluation Cost


### Evaluation (attribute resolution)

| Command | Result | Time |
|---|---|---|
| nix flake show | ✓ | 62.13s |
| packages.x86_64-linux | ✓ | 0.06s |
| apps.x86_64-linux | ✓ | 0.06s |
| checks.x86_64-linux | ✓ | 0.06s |

### Build (realisation)

| Command | Result | Time |
|---|---|---|
| nix flake check | ✓ | 64.47s |
## 26. Technical Debt Score


### Architecture

- ✓ No cyclic imports
- ✓ parseEnv imported from 0 files

### Portability

- ⚠ 7 architecture-specific literals (x86_64-linux)
- ✓ 0 repository path literals (proj/angst)
- ✓ 0 files reference /nix/store

### Configuration

- ✓ All domains have default.nix

### Evaluation

- ✓ Statix clean
- ✓ No dead code (deadnix clean)
## 27. Hotspot Table

> Cross-references file size, git churn, dependency counts, and complexity into a single view.

> **Columns**: LOC (size), Churn (commits/year), Imports (fan-out), Dependents (fan-in), Complexity (derived from nesting depth, string interpolation, conditional count).

| File | LOC | Churn | Imports | Dependents | Complexity | Score |
|---|---|---|---|---|---|---|
| `domains/git/lazygit/render.nix` | 341 | 4 | 0 | 0 | Medium | 4 |
| `domains/shell/starship/modules.nix` | 268 | 3 | 0 | 1 | Low | 2 |
| `themes/default.nix` | 264 | 13 | 1 | 1 | Very High | 7 |
| `domains/terminal/zellij/render.nix` | 258 | 22 | 2 | 0 | High | 5 |
| `checks/vault-pipeline.nix` | 250 | 2 | 0 | 1 | Low | 2 |
| `runtime/default.nix` | 243 | 16 | 23 | 0 | High | 5 |
| `lib/domains/module.nix` | 236 | 27 | 1 | 1 | Very High | 9 |
| `lib/flake/context.nix` | 212 | 12 | 7 | 1 | Medium | 3 |
| `domains/shell/nushell/render.nix` | 191 | 11 | 0 | 0 | Very High | 8 |
| `checks/secrets.nix` | 187 | 9 | 0 | 1 | Low | 2 |
| `lib/build/mkNixos.nix` | 185 | 38 | 4 | 1 | High | 5 |
| `modules/vm/vm-profile.nix` | 182 | 21 | 0 | 0 | Very High | 9 |
| `domains/sql-client/sqlit/render.nix` | 177 | 10 | 0 | 0 | High | 6 |
| `domains/shell/starship/render.nix` | 162 | 17 | 1 | 0 | High | 6 |
| `lib/domains/mkDomain.nix` | 159 | 4 | 0 | 1 | High | 5 |
| `checks/projects-pipeline.nix` | 155 | 7 | 0 | 1 | Low | 2 |
| `domains/terminal/zellij/theme.nix` | 151 | 2 | 0 | 1 | High | 5 |
| `checks/default.nix` | 148 | 14 | 15 | 1 | Low | 2 |
| `domains/wm/i3/render.nix` | 146 | 6 | 0 | 0 | High | 5 |
| `lib/resolve.nix` | 129 | 15 | 4 | 1 | Low | 2 |
| `domains/launcher/rofi/render.nix` | 128 | 6 | 0 | 0 | Low | 1 |
| `checks/ftp-pipeline.nix` | 121 | 5 | 0 | 1 | Low | 1 |
| `checks/secret-scan.nix` | 107 | 5 | 0 | 1 | Low | 2 |
| `domains/remote/ssh/ssh-config.nix` | 99 | 1 | 0 | 0 | Medium | 3 |
| `domains/remote/ftp/home.nix` | 98 | 6 | 0 | 0 | Medium | 3 |
## 28. Stability Index

> Cross-references git churn with file recency. **Hot** = high churn + recently modified, **Active** = moderate churn, **Stable** = low churn, **Archived** = no changes in 6+ months.

| File | Churn | Last changed | Label |
|---|---|---|---|
| `lib/build/mkHome.nix` | 59 | 2026-08-24 | Hot |
| `flake.nix` | 43 | 2026-08-24 | Hot |
| `lib/build/mkNixos.nix` | 38 | 2026-08-25 | Hot |
| `lib/domains/module.nix` | 27 | 2026-08-24 | Hot |
| `domains/terminal/zellij/render.nix` | 22 | 2026-08-15 | Hot |
| `modules/vm/vm-profile.nix` | 21 | 2026-08-21 | Hot |
| `hosts/vm/default.nix` | 20 | 2026-08-25 | Hot |
| `domains/shell/starship/render.nix` | 17 | 2026-08-15 | Hot |
| `runtime/default.nix` | 16 | 2026-08-24 | Hot |
| `lib/flake/outputs.nix` | 15 | 2026-08-13 | Hot |
| `lib/resolve.nix` | 15 | 2026-08-25 | Hot |
| `themes/miasma.nix` | 14 | 2026-08-06 | Hot |
| `checks/default.nix` | 14 | 2026-08-19 | Hot |
| `hosts/personal/nixos/default.nix` | 14 | 2026-08-21 | Hot |
| `hosts/personal/mint/default.nix` | 14 | 2026-08-24 | Hot |
| `themes/default.nix` | 13 | 2026-08-06 | Hot |
| `modules/secrets.nix` | 13 | 2026-08-21 | Hot |
| `profiles/base.nix` | 12 | 2026-08-21 | Hot |
| `lib/flake/context.nix` | 12 | 2026-08-24 | Hot |
| `lib/flake/devshell.nix` | 12 | 2026-08-25 | Hot |
## 29. Theme × Domain Coverage

> ✓ = render produces output, ✗ = render throws, — = no render.nix

| Theme | agents/cursor-cli | agents/opencode | bar/i3status | editor/nvim | embedded/arduino | files/yazi | git/lazygit | git/projects | http-client/posting | launcher/rofi | nix/nh | remote/ftp | remote/ssh | security/age | session/x11 | shell/carapace | shell/nushell | shell/starship | sql-client/rainfrog | sql-client/sqlit | system/audio | system/clipboard | system/container | system/git | system/graphical | system/monitoring | system/network | system/search | terminal/ghostty | terminal/tmux | terminal/zellij | wm/i3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `catppuccin-mocha` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `github` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `gotham` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `kanagawa` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `lotus` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `miasma` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `monochrome` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `noctis` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
| `rose-pine` | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | — | — | — | — | — | ✓ | ✓ | ✓ | ✓ |
## 30. Domain Features

> Which optional features each domain provides.

| Domain | render | system/home | config/ | module |
|---|---|---|---|---|
| agents/cursor-cli | — | ✓ | — | ✓ |
| agents/opencode | ✓ | ✓ | ✓ | ✓ |
| bar/i3status | ✓ | ✓ | ✓ | ✓ |
| editor/nvim | ✓ | ✓ | ✓ | ✓ |
| embedded/arduino | — | ✓ | — | ✓ |
| files/yazi | ✓ | ✓ | ✓ | ✓ |
| git/lazygit | ✓ | ✓ | ✓ | ✓ |
| git/projects | — | ✓ | — | ✓ |
| http-client/posting | ✓ | ✓ | ✓ | ✓ |
| launcher/rofi | ✓ | ✓ | ✓ | ✓ |
| nix/nh | — | — | — | — |
| remote/ftp | — | ✓ | — | ✓ |
| remote/ssh | — | ✓ | — | ✓ |
| security/age | — | — | — | — |
| session/x11 | ✓ | ✓ | ✓ | ✓ |
| shell/carapace | — | ✓ | — | ✓ |
| shell/nushell | ✓ | ✓ | ✓ | ✓ |
| shell/starship | ✓ | ✓ | ✓ | ✓ |
| sql-client/rainfrog | ✓ | ✓ | ✓ | ✓ |
| sql-client/sqlit | ✓ | ✓ | ✓ | ✓ |
| system/audio | — | ✓ | — | ✓ |
| system/clipboard | — | ✓ | — | ✓ |
| system/container | — | ✓ | — | ✓ |
| system/git | — | ✓ | — | ✓ |
| system/graphical | — | ✓ | — | ✓ |
| system/monitoring | — | ✓ | — | ✓ |
| system/network | — | ✓ | — | ✓ |
| system/search | — | ✓ | — | ✓ |
| terminal/ghostty | ✓ | ✓ | ✓ | ✓ |
| terminal/tmux | ✓ | ✓ | ✓ | ✓ |
| terminal/zellij | ✓ | ✓ | ✓ | ✓ |
| wm/i3 | ✓ | ✓ | ✓ | ✓ |
## 31. Check Results Breakdown

| Check | Result | Time | Details |
|---|---|---|---|
| `build-all` | ✗ | 90.44s | evaluation warning: stdenv.isLinux is deprecated, use stdenv.hostPlatform.isLinux instead evaluation warning: stdenv.isDarwin is deprecated, use stdenv.hostPlatform.isDarwin instead evaluation warning: stdenv.isLinux is deprecated, use stdenv.hostPlatform.isLinux instead evaluation warning: stdenv.i |
| `check-ftp-encrypted` | ✓ | 0.97s |  |
| `check-ftp-pipeline` | ✓ | 2.02s |  |
| `check-password` | ✓ | 0.47s |  |
| `check-projects-encrypted` | ✓ | 0.76s |  |
| `check-projects-ftp-declared` | ✓ | 0.79s |  |
| `check-projects-pipeline` | ✓ | 1.22s |  |
| `check-secrets-encrypted` | ✓ | 0.75s |  |
| `check-ssh-keys` | ✓ | 1.34s |  |
| `check-vault-pipeline` | ✗ | 1.39s | this derivation will be built:   /nix/store/grrmckbp7q45zga8xdisqlycy0rb83s6-check-vault-pipeline.drv building '/nix/store/grrmckbp7q45zga8xdisqlycy0rb83s6-check-vault-pipeline.drv'... error: Cannot build '/nix/store/grrmckbp7q45zga8xdisqlycy0rb83s6-check-vault-pipeline.drv'.        Reason: builder  |
| `eval-all` | ✓ | 60.84s |  |
| `home-theme-override-test` | ✓ | 14.05s |  |
| `lint-desktop` | ✓ | 1.93s |  |
| `lint-nix` | ✓ | 1.46s |  |
| `lint-shell` | ✓ | 1.25s |  |
| `lint-themes` | ✓ | 0.57s |  |
| `login-shell-invalid` | ✓ | 1.06s |  |
| `login-shell-valid` | ✓ | 0.44s |  |
| `secret-scan` | ✓ | 7.00s |  |
| `secret-scan-hooks` | ✓ | 1.72s |  |
| `theme-override` | ✓ | 1.09s |  |
| `theme-rendered` | ✓ | 0.58s |  |
| `theme-semantic-distinct` | ✓ | 0.48s |  |

**21 passed, 2 failed**


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
  domains/agents/opencode/config/tui.json render + catppuccin-mocha: ok
  domains/agents/opencode/config/themes/angst.json render + catppuccin-mocha: ok
  domains/bar/i3status/config/config render + catppuccin-mocha: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + catppuccin-mocha: ok
  domains/files/yazi/config/theme.toml render + catppuccin-mocha: ok
  domains/git/lazygit/config/config.yml render + catppuccin-mocha: ok
  domains/http-client/posting/config/config.yaml render + catppuccin-mocha: ok
  domains/http-client/posting/config/themes/angst.yaml render + catppuccin-mocha: ok
  domains/launcher/rofi/config/config.rasi render + catppuccin-mocha: ok
  domains/launcher/rofi/config/theme.rasi render + catppuccin-mocha: ok
  domains/session/x11/config/xinitrc render + catppuccin-mocha: ok
  domains/shell/nushell/config/colors.nu render + catppuccin-mocha: ok
  domains/shell/nushell/config/ssh-agent.nu render + catppuccin-mocha: ok
  domains/shell/starship/config/starship.toml render + catppuccin-mocha: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + catppuccin-mocha: ok
  domains/sql-client/sqlit/config/settings.json render + catppuccin-mocha: ok
  domains/sql-client/sqlit/config/themes/catppuccin-mocha.json render + catppuccin-mocha: ok
  domains/sql-client/sqlit/config/connections.json render + catppuccin-mocha: ok
  domains/terminal/ghostty/config/config.ghostty render + catppuccin-mocha: ok
  domains/terminal/ghostty/config/colors.conf render + catppuccin-mocha: ok
  domains/terminal/tmux/config/tmux.conf render + catppuccin-mocha: ok
  domains/terminal/zellij/config/config.kdl render + catppuccin-mocha: ok
  domains/terminal/zellij/config/themes/angst.kdl render + catppuccin-mocha: ok
  domains/terminal/zellij/config/layouts/default.kdl render + catppuccin-mocha: ok
  domains/wm/i3/config/monitors.conf render + catppuccin-mocha: ok
  domains/wm/i3/config/config render + catppuccin-mocha: ok
  domains/agents/opencode/config/tui.json render + github: ok
  domains/agents/opencode/config/themes/angst.json render + github: ok
  domains/bar/i3status/config/config render + github: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + github: ok
  domains/files/yazi/config/theme.toml render + github: ok
  domains/git/lazygit/config/config.yml render + github: ok
  domains/http-client/posting/config/config.yaml render + github: ok
  domains/http-client/posting/config/themes/angst.yaml render + github: ok
  domains/launcher/rofi/config/config.rasi render + github: ok
  domains/launcher/rofi/config/theme.rasi render + github: ok
  domains/session/x11/config/xinitrc render + github: ok
  domains/shell/nushell/config/colors.nu render + github: ok
  domains/shell/nushell/config/ssh-agent.nu render + github: ok
  domains/shell/starship/config/starship.toml render + github: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + github: ok
  domains/sql-client/sqlit/config/settings.json render + github: ok
  domains/sql-client/sqlit/config/themes/github.json render + github: ok
  domains/sql-client/sqlit/config/connections.json render + github: ok
  domains/terminal/ghostty/config/config.ghostty render + github: ok
  domains/terminal/ghostty/config/colors.conf render + github: ok
  domains/terminal/tmux/config/tmux.conf render + github: ok
  domains/terminal/zellij/config/config.kdl render + github: ok
  domains/terminal/zellij/config/themes/angst.kdl render + github: ok
  domains/terminal/zellij/config/layouts/default.kdl render + github: ok
  domains/wm/i3/config/monitors.conf render + github: ok
  domains/wm/i3/config/config render + github: ok
  domains/agents/opencode/config/tui.json render + gotham: ok
  domains/agents/opencode/config/themes/angst.json render + gotham: ok
  domains/bar/i3status/config/config render + gotham: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + gotham: ok
  domains/files/yazi/config/theme.toml render + gotham: ok
  domains/git/lazygit/config/config.yml render + gotham: ok
  domains/http-client/posting/config/config.yaml render + gotham: ok
  domains/http-client/posting/config/themes/angst.yaml render + gotham: ok
  domains/launcher/rofi/config/config.rasi render + gotham: ok
  domains/launcher/rofi/config/theme.rasi render + gotham: ok
  domains/session/x11/config/xinitrc render + gotham: ok
  domains/shell/nushell/config/colors.nu render + gotham: ok
  domains/shell/nushell/config/ssh-agent.nu render + gotham: ok
  domains/shell/starship/config/starship.toml render + gotham: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + gotham: ok
  domains/sql-client/sqlit/config/settings.json render + gotham: ok
  domains/sql-client/sqlit/config/themes/gotham.json render + gotham: ok
  domains/sql-client/sqlit/config/connections.json render + gotham: ok
  domains/terminal/ghostty/config/config.ghostty render + gotham: ok
  domains/terminal/ghostty/config/colors.conf render + gotham: ok
  domains/terminal/tmux/config/tmux.conf render + gotham: ok
  domains/terminal/zellij/config/config.kdl render + gotham: ok
  domains/terminal/zellij/config/themes/angst.kdl render + gotham: ok
  domains/terminal/zellij/config/layouts/default.kdl render + gotham: ok
  domains/wm/i3/config/monitors.conf render + gotham: ok
  domains/wm/i3/config/config render + gotham: ok
  domains/agents/opencode/config/tui.json render + kanagawa: ok
  domains/agents/opencode/config/themes/angst.json render + kanagawa: ok
  domains/bar/i3status/config/config render + kanagawa: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + kanagawa: ok
  domains/files/yazi/config/theme.toml render + kanagawa: ok
  domains/git/lazygit/config/config.yml render + kanagawa: ok
  domains/http-client/posting/config/config.yaml render + kanagawa: ok
  domains/http-client/posting/config/themes/angst.yaml render + kanagawa: ok
  domains/launcher/rofi/config/config.rasi render + kanagawa: ok
  domains/launcher/rofi/config/theme.rasi render + kanagawa: ok
  domains/session/x11/config/xinitrc render + kanagawa: ok
  domains/shell/nushell/config/colors.nu render + kanagawa: ok
  domains/shell/nushell/config/ssh-agent.nu render + kanagawa: ok
  domains/shell/starship/config/starship.toml render + kanagawa: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + kanagawa: ok
  domains/sql-client/sqlit/config/settings.json render + kanagawa: ok
  domains/sql-client/sqlit/config/themes/kanagawa.json render + kanagawa: ok
  domains/sql-client/sqlit/config/connections.json render + kanagawa: ok
  domains/terminal/ghostty/config/config.ghostty render + kanagawa: ok
  domains/terminal/ghostty/config/colors.conf render + kanagawa: ok
  domains/terminal/tmux/config/tmux.conf render + kanagawa: ok
  domains/terminal/zellij/config/config.kdl render + kanagawa: ok
  domains/terminal/zellij/config/themes/angst.kdl render + kanagawa: ok
  domains/terminal/zellij/config/layouts/default.kdl render + kanagawa: ok
  domains/wm/i3/config/monitors.conf render + kanagawa: ok
  domains/wm/i3/config/config render + kanagawa: ok
  domains/agents/opencode/config/tui.json render + lotus: ok
  domains/agents/opencode/config/themes/angst.json render + lotus: ok
  domains/bar/i3status/config/config render + lotus: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + lotus: ok
  domains/files/yazi/config/theme.toml render + lotus: ok
  domains/git/lazygit/config/config.yml render + lotus: ok
  domains/http-client/posting/config/config.yaml render + lotus: ok
  domains/http-client/posting/config/themes/angst.yaml render + lotus: ok
  domains/launcher/rofi/config/config.rasi render + lotus: ok
  domains/launcher/rofi/config/theme.rasi render + lotus: ok
  domains/session/x11/config/xinitrc render + lotus: ok
  domains/shell/nushell/config/colors.nu render + lotus: ok
  domains/shell/nushell/config/ssh-agent.nu render + lotus: ok
  domains/shell/starship/config/starship.toml render + lotus: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + lotus: ok
  domains/sql-client/sqlit/config/settings.json render + lotus: ok
  domains/sql-client/sqlit/config/themes/lotus.json render + lotus: ok
  domains/sql-client/sqlit/config/connections.json render + lotus: ok
  domains/terminal/ghostty/config/config.ghostty render + lotus: ok
  domains/terminal/ghostty/config/colors.conf render + lotus: ok
  domains/terminal/tmux/config/tmux.conf render + lotus: ok
  domains/terminal/zellij/config/config.kdl render + lotus: ok
  domains/terminal/zellij/config/themes/angst.kdl render + lotus: ok
  domains/terminal/zellij/config/layouts/default.kdl render + lotus: ok
  domains/wm/i3/config/monitors.conf render + lotus: ok
  domains/wm/i3/config/config render + lotus: ok
  domains/agents/opencode/config/tui.json render + miasma: ok
  domains/agents/opencode/config/themes/angst.json render + miasma: ok
  domains/bar/i3status/config/config render + miasma: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + miasma: ok
  domains/files/yazi/config/theme.toml render + miasma: ok
  domains/git/lazygit/config/config.yml render + miasma: ok
  domains/http-client/posting/config/config.yaml render + miasma: ok
  domains/http-client/posting/config/themes/angst.yaml render + miasma: ok
  domains/launcher/rofi/config/config.rasi render + miasma: ok
  domains/launcher/rofi/config/theme.rasi render + miasma: ok
  domains/session/x11/config/xinitrc render + miasma: ok
  domains/shell/nushell/config/colors.nu render + miasma: ok
  domains/shell/nushell/config/ssh-agent.nu render + miasma: ok
  domains/shell/starship/config/starship.toml render + miasma: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + miasma: ok
  domains/sql-client/sqlit/config/settings.json render + miasma: ok
  domains/sql-client/sqlit/config/themes/miasma.json render + miasma: ok
  domains/sql-client/sqlit/config/connections.json render + miasma: ok
  domains/terminal/ghostty/config/config.ghostty render + miasma: ok
  domains/terminal/ghostty/config/colors.conf render + miasma: ok
  domains/terminal/tmux/config/tmux.conf render + miasma: ok
  domains/terminal/zellij/config/config.kdl render + miasma: ok
  domains/terminal/zellij/config/themes/angst.kdl render + miasma: ok
  domains/terminal/zellij/config/layouts/default.kdl render + miasma: ok
  domains/wm/i3/config/monitors.conf render + miasma: ok
  domains/wm/i3/config/config render + miasma: ok
  domains/agents/opencode/config/tui.json render + monochrome: ok
  domains/agents/opencode/config/themes/angst.json render + monochrome: ok
  domains/bar/i3status/config/config render + monochrome: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + monochrome: ok
  domains/files/yazi/config/theme.toml render + monochrome: ok
  domains/git/lazygit/config/config.yml render + monochrome: ok
  domains/http-client/posting/config/config.yaml render + monochrome: ok
  domains/http-client/posting/config/themes/angst.yaml render + monochrome: ok
  domains/launcher/rofi/config/config.rasi render + monochrome: ok
  domains/launcher/rofi/config/theme.rasi render + monochrome: ok
  domains/session/x11/config/xinitrc render + monochrome: ok
  domains/shell/nushell/config/colors.nu render + monochrome: ok
  domains/shell/nushell/config/ssh-agent.nu render + monochrome: ok
  domains/shell/starship/config/starship.toml render + monochrome: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + monochrome: ok
  domains/sql-client/sqlit/config/settings.json render + monochrome: ok
  domains/sql-client/sqlit/config/themes/monochrome.json render + monochrome: ok
  domains/sql-client/sqlit/config/connections.json render + monochrome: ok
  domains/terminal/ghostty/config/config.ghostty render + monochrome: ok
  domains/terminal/ghostty/config/colors.conf render + monochrome: ok
  domains/terminal/tmux/config/tmux.conf render + monochrome: ok
  domains/terminal/zellij/config/config.kdl render + monochrome: ok
  domains/terminal/zellij/config/themes/angst.kdl render + monochrome: ok
  domains/terminal/zellij/config/layouts/default.kdl render + monochrome: ok
  domains/wm/i3/config/monitors.conf render + monochrome: ok
  domains/wm/i3/config/config render + monochrome: ok
  domains/agents/opencode/config/tui.json render + noctis: ok
  domains/agents/opencode/config/themes/angst.json render + noctis: ok
  domains/bar/i3status/config/config render + noctis: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + noctis: ok
  domains/files/yazi/config/theme.toml render + noctis: ok
  domains/git/lazygit/config/config.yml render + noctis: ok
  domains/http-client/posting/config/config.yaml render + noctis: ok
  domains/http-client/posting/config/themes/angst.yaml render + noctis: ok
  domains/launcher/rofi/config/config.rasi render + noctis: ok
  domains/launcher/rofi/config/theme.rasi render + noctis: ok
  domains/session/x11/config/xinitrc render + noctis: ok
  domains/shell/nushell/config/colors.nu render + noctis: ok
  domains/shell/nushell/config/ssh-agent.nu render + noctis: ok
  domains/shell/starship/config/starship.toml render + noctis: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + noctis: ok
  domains/sql-client/sqlit/config/settings.json render + noctis: ok
  domains/sql-client/sqlit/config/themes/noctis.json render + noctis: ok
  domains/sql-client/sqlit/config/connections.json render + noctis: ok
  domains/terminal/ghostty/config/config.ghostty render + noctis: ok
  domains/terminal/ghostty/config/colors.conf render + noctis: ok
  domains/terminal/tmux/config/tmux.conf render + noctis: ok
  domains/terminal/zellij/config/config.kdl render + noctis: ok
  domains/terminal/zellij/config/themes/angst.kdl render + noctis: ok
  domains/terminal/zellij/config/layouts/default.kdl render + noctis: ok
  domains/wm/i3/config/monitors.conf render + noctis: ok
  domains/wm/i3/config/config render + noctis: ok
  domains/agents/opencode/config/tui.json render + rose-pine: ok
  domains/agents/opencode/config/themes/angst.json render + rose-pine: ok
  domains/bar/i3status/config/config render + rose-pine: ok
  domains/editor/nvim/config/lua/config/theme/palette.lua render + rose-pine: ok
  domains/files/yazi/config/theme.toml render + rose-pine: ok
  domains/git/lazygit/config/config.yml render + rose-pine: ok
  domains/http-client/posting/config/config.yaml render + rose-pine: ok
  domains/http-client/posting/config/themes/angst.yaml render + rose-pine: ok
  domains/launcher/rofi/config/config.rasi render + rose-pine: ok
  domains/launcher/rofi/config/theme.rasi render + rose-pine: ok
  domains/session/x11/config/xinitrc render + rose-pine: ok
  domains/shell/nushell/config/colors.nu render + rose-pine: ok
  domains/shell/nushell/config/ssh-agent.nu render + rose-pine: ok
  domains/shell/starship/config/starship.toml render + rose-pine: ok
  domains/sql-client/rainfrog/config/rainfrog_config.toml render + rose-pine: ok
  domains/sql-client/sqlit/config/settings.json render + rose-pine: ok
  domains/sql-client/sqlit/config/themes/rose-pine.json render + rose-pine: ok
  domains/sql-client/sqlit/config/connections.json render + rose-pine: ok
  domains/terminal/ghostty/config/config.ghostty render + rose-pine: ok
  domains/terminal/ghostty/config/colors.conf render + rose-pine: ok
  domains/terminal/tmux/config/tmux.conf render + rose-pine: ok
  domains/terminal/zellij/config/config.kdl render + rose-pine: ok
  domains/terminal/zellij/config/themes/angst.kdl render + rose-pine: ok
  domains/terminal/zellij/config/layouts/default.kdl render + rose-pine: ok
  domains/wm/i3/config/monitors.conf render + rose-pine: ok
  domains/wm/i3/config/config render + rose-pine: ok

All theme checks passed.
```
## 32. Rendered Output Sizes

> Estimated output lines from multi-line string literals in render.nix.

| Domain | Output files | Est. output lines |
|---|---|---|
| git/lazygit | 1 | 323 |
| terminal/zellij | 3 | 138 |
| launcher/rofi | 2 | 105 |
| shell/nushell | 2 | 101 |
| wm/i3 | 2 | 99 |
| terminal/ghostty | 2 | 50 |
| shell/starship | 1 | 46 |
| terminal/tmux | 1 | 37 |
| sql-client/sqlit | 3 | 29 |
| http-client/posting | 2 | 24 |
| editor/nvim | 1 | 16 |
| files/yazi | 1 | 14 |
| bar/i3status | 1 | 14 |
| sql-client/rainfrog | 1 | 8 |
| session/x11 | 1 | 4 |
| agents/opencode | 2 | 0 |
## 33. Growth Velocity

> Monthly lines added/removed across .nix, .sh, and .rs files (excludes merges).

| Month | Added | Removed | Net | Commits |
|---|---|---|---|---|
| 2026-06 | 10483 | 4442 | +6041 | 108 |
| 2026-07 | 10652 | 8282 | +2370 | 144 |
| 2026-08 | 11785 | 10998 | +787 | 113 |

> **12-month totals:** +32920 added, −23722 removed, net +9198
## 34. Theme Token Usage Audit

> How many times each schema token is referenced in each render.nix.

> Token lookup uses regex patterns covering `${p.xxx}`, `${t.safe.xxx}`, `${a.xxx}`, and `${t.ansi.xxx}` references.


### Per-domain usage

| Domain | bg·base | bg·variant | sf·base | sf·variant | fg·base | fg·variant | ac·base | ac·variant | dim | ansi·error | ansi·warn | ansi·info | ansi·success |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| agents/opencode | 3 | 6 | — | 1 | 5 | 11 | 13 | — | 3 | 3 | 1 | 1 | 3 |
| bar/i3status | — | — | — | — | — | 1 | — | — | — | 1 | 1 | — | 1 |
| editor/nvim | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| files/yazi | 1 | 2 | 1 | 1 | — | 2 | — | 1 | 1 | — | — | — | — |
| git/lazygit | — | — | — | 2 | 3 | 1 | 2 | 2 | — | 1 | — | — | — |
| http-client/posting | 1 | 1 | 1 | — | 1 | 1 | — | 1 | — | 1 | 1 | — | 1 |
| launcher/rofi | — | 1 | — | — | — | 2 | 1 | — | — | — | — | — | — |
| session/x11 | 1 | — | — | — | — | — | — | — | — | — | — | — | — |
| shell/nushell | 1 | — | 3 | 2 | 24 | 11 | 12 | 1 | 16 | — | — | — | — |
| shell/starship | — | — | — | 3 | 3 | 1 | 3 | 1 | 1 | 7 | 1 | — | 2 |
| sql-client/rainfrog | — | — | — | — | — | — | — | — | — | — | — | — | — |
| sql-client/sqlit | 8 | 1 | 3 | — | 4 | 2 | 1 | 3 | — | 3 | 2 | — | 3 |
| terminal/ghostty | 1 | 1 | 2 | 2 | 2 | 5 | 3 | 4 | 4 | — | — | — | — |
| terminal/tmux | 1 | — | — | 13 | — | — | 4 | 2 | — | — | — | — | — |
| terminal/zellij | 13 | 2 | 3 | 7 | 4 | 1 | 8 | 4 | 1 | — | 2 | — | 1 |
| wm/i3 | 16 | — | — | — | 4 | 1 | 4 | — | 3 | 3 | 2 | 3 | — |

### Token popularity summary

| Token | Total uses | Used by (domains) |
|---|---|---|
| `palette.ac.base` | 52 | 11 |
| `palette.fg.base` | 51 | 10 |
| `palette.bg.base` | 47 | 11 |
| `palette.fg.variant` | 40 | 13 |
| `palette.sf.variant` | 32 | 9 |
| `palette.dim` | 30 | 8 |
| `ansi.error` | 20 | 8 |
| `palette.ac.variant` | 20 | 10 |
| `palette.bg.variant` | 15 | 8 |
| `palette.sf.base` | 14 | 7 |
| `ansi.success` | 12 | 7 |
| `ansi.warn` | 11 | 8 |
| `ansi.info` | 5 | 3 |
## 35. Eval Memory (peak RSS)

> Peak RSS via `/usr/bin/time -v` (`Maximum resident set size`), wall time; budget **4 GiB** aggregated, **3 GiB** per-host (`nixos` canary). `nixos` is heaviest (base+desktop+development+embedded, toolchains="*").

| Attr | maxRSS | wall | result |
|---|---|---|---|
| `checks.x86_64-linux.build-all` | 6.1 GiB | 90.5s | ✓ |
| `checks.x86_64-linux.eval-all` | 3.9 GiB | 68.2s | ✓ |
| `homeConfigurations.ci.activationPackage` | 951 MiB | 14.4s | ✓ |
| `homeConfigurations.home.activationPackage` | 1.3 GiB | 22.2s | ✓ |
| `homeConfigurations.mint.activationPackage` | 1.4 GiB | 23.1s | ✓ |
| `homeConfigurations.nixos.activationPackage` | 1.4 GiB | 22.9s | ✓ |
| `homeConfigurations.runner-theme-override-test.activationPackage` | 951 MiB | 14.1s | ✓ |
| `homeConfigurations.runner.activationPackage` | 951 MiB | 12.9s | ✓ |
| `homeConfigurations.vm.activationPackage` | 1.4 GiB | 21.7s | ✓ |
| `nixosConfigurations.ci.config.system.build.toplevel` | 1.1 GiB | 11.2s | ✓ |
| `nixosConfigurations.nixos.config.system.build.toplevel` | 1.4 GiB | 19.8s | ✓ |
| `nixosConfigurations.vm.config.system.build.toplevel` | 1.4 GiB | 18.9s | ✓ |

### Gates (4 GiB aggregated, 3 GiB per-host)

| Attr | Gate | maxRSS | Limit |
|---|---|---|---|
| `checks.x86_64-linux.build-all` | ✗ >4096 MiB | 6.1 GiB | ≤4096 MiB |
| `checks.x86_64-linux.eval-all` | ✓ | 3.9 GiB | ≤4096 MiB |
| `homeConfigurations.ci.activationPackage` | ✓ | 951 MiB | ≤3072 MiB |
| `homeConfigurations.home.activationPackage` | ✓ | 1.3 GiB | ≤3072 MiB |
| `homeConfigurations.mint.activationPackage` | ✓ | 1.4 GiB | ≤3072 MiB |
| `homeConfigurations.nixos.activationPackage` | ✓ | 1.4 GiB | ≤3072 MiB |
| `homeConfigurations.runner-theme-override-test.activationPackage` | ✓ | 951 MiB | ≤3072 MiB |
| `homeConfigurations.runner.activationPackage` | ✓ | 951 MiB | ≤3072 MiB |
| `homeConfigurations.vm.activationPackage` | ✓ | 1.4 GiB | ≤3072 MiB |
| `nixosConfigurations.ci.config.system.build.toplevel` | ✓ | 1.1 GiB | ≤3072 MiB |
| `nixosConfigurations.nixos.config.system.build.toplevel` | ✓ | 1.4 GiB | ≤3072 MiB |
| `nixosConfigurations.vm.config.system.build.toplevel` | ✓ | 1.4 GiB | ≤3072 MiB |

> Full JSON: `analysis-memory.json`

---

*Analysis complete.*
