# Fix Plan

*Generated: 2026-07-19*

## Priority 1: Unblock flake evaluation (critical)

**`local/config.nix` requirement breaks all nix commands**

- [ ] Make `lib/read-config.nix` graceful when `local/config.nix` is missing: use defaults instead of `throw`
- [ ] Or add a `local/config.nix.example`-based fallback in the flake itself

**Impact**: unblocks `nix flake show`, `nix flake check`, all attribute resolution

---

## Priority 2: Layer violations (architecture)

**7 violations of allowed dependency direction**

- [ ] Extract `profiles/` into `lib/profiles/` — `lib/profiles.nix` importing `profiles/*` crosses below lib layer
- [ ] Decouple `capabilities/graphical.nix` from `themes/default.nix` — capabilities must not depend on themes. Pass theme as parameter or move theme logic upstream
- [ ] Decouple `lib/read-config.nix` from `themes/default.nix` — same reasoning. Inject theme via parameter

---

## Priority 3: Deduplication

**`allowUnfree` hardcoded in 6 files**

- [ ] Consolidate into `lib/nixpkgs-config.nix` (or similar single source)
- [ ] Import from `flake.nix`, `lib/outputs.nix`, `lib/nixos/default.nix`, `lib/build/mkHome.nix`, `lib/build/mkHost.nix`
- [ ] Eliminate the duplicate in `lib/read-config.nix` entirely (it already reads nixpkgs config there)

---

## Priority 4: Error handling

**12 `builtins.throw` in runtime paths**

- [ ] Replace validation throws (`themes/default.nix`, `lib/domains/scan.nix`) with `assert` where appropriate
- [ ] Add context to throws so error messages include file location automatically
- [ ] Consider `lib.assertMsg` or `lib.assertOneOf` for domain/theme validation

---

## Priority 5: Tooling gaps

**No deadnix or statix in checks**

- [ ] Add `deadnix` and `statix` to `flake.nix` devShell or check inputs
- [ ] Run `nix shell nixpkgs#deadnix nixpkgs#statix --command deadnix ./ && statix ./` in checks
- [ ] Configure statix with `statix.toml` to exclude false positives

---

## Priority 6: High-complexity domains (maintenance risk)

**Starship (423 LOC) and Zellij (423 LOC) renders dominate complexity metrics**

- [ ] Break `domains/shell/starship/render.nix` into smaller modules (e.g., `format.nix`, `palette.nix`)
- [ ] Break `domains/terminal/zellij/render.nix` similarly
- [ ] Extract shared rendering helpers into `lib/render-helpers.nix` if patterns emerge

---

## Priority 7: Domain maturity

**7/16 domains at maturity score ≤ 1**

- [ ] Add home-manager modules to: `git/lazygit`, `http-client/posting`, `llm/opencode`, `sql-client/sqlit`
- [ ] Add render to: `session/x11`, `terminal/tmux`, `llm/cursor-cli`
- [ ] Add activation scripts to domains that need them (e.g., `git/lazygit`)
- [ ] Drop or clearly deprecate `llm/cursor-cli` if not planned (score 0, skeleton)
