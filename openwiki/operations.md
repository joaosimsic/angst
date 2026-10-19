# Operations

Runbook and operational notes: dev shells, checks/CI, git hooks, justfile recipes, VM workflow, and machine lifecycle.

## Development Shells

| Shell | Use | Includes |
|---|---|---|
| `nix develop .#safe` | Editing configs | neovim, git, deadnix, statix + toolchain packages |
| `nix develop .#dev` | Full development | `safe` + angst CLI, openssh, qemu, age, gitleaks, Rust toolchain, VM tools; exports `VM_SSH_PORT=2222`, `NIX_DEFAULT_TARGET_HOST`; ssh-agent init |
| `nix develop .#vm` | Rust VM workspace | `inputsFrom` vm dev shell + dev packages |

Standalone: `nix run .#shell -- dev` / `nix profile install .#shell && shell dev` (see [Tools](tools.md)).

## Checks

`nix flake check` (or `nix run .#check`) runs everything below; targeted lints are faster for iteration. Defined in `checks/default.nix`:

| Check | Validates |
|---|---|
| `lint-themes` | All 9 themes load and validate (eval-only, fast) |
| `lint-desktop` | i3 + i3status configs parse per theme |
| `lint-shell` | starship.toml (`taplo check`) + nushell colors per theme |
| `theme-rendered` | Rendered domain configs contain expected theme tokens (`checks/theme/rendered.nix`) |
| `theme-override` | Theme override propagates into a real home config (`home-theme-override-test`) |
| `theme-semantic-distinct` | `ansi.error/warn/info/success` mutually distinct |
| `check-password` | Host `password` field is a valid `$6$` sha-512 hash (skips home-only/`!` hosts) |
| `check-secrets-encrypted` | Every `secrets/master/*.age` is age-encrypted (`age-encryption.org/v1` envelope) |
| `check-ftp-encrypted` | Every `secrets/ftp/*` is age-encrypted (age envelope, no plaintext server fields) |
| `check-projects-ftp-declared` | Host-declared `projects` ids exist in the encrypted store; host-declared ftp `configFile`s exist + are encrypted + use a safe `mountPoint` |
| `check-projects-pipeline` | Functional round trip with throwaway age keys: export → leak-free encrypted store → byte-exact import; sync materializes `.env` (0600), store-change updates it, local edits are never clobbered (status `STALE`) |
| `check-ftp-pipeline` | Functional pipeline: sample rclone config encrypted to a throwaway work key → decrypted by the real `angst-ftp-secrets-home` script into `~/.secrets/ftp` (0600/0700) → JSON→INI transform parses via `rclone listremotes` |
| `login-shell-valid` / `login-shell-invalid` | `shellOverride` handling: valid shell builds, invalid shell asserts |
| `home-theme-override-test` | Builds a representative home config with an alternate theme |
| `lint-nix` | `deadnix --fail` + `statix check .` |

Formatting is enforced by the `formatter` output (`nix fmt` → nixfmt) and CI also runs `shfmt --diff` and `cargo fmt --check` for `tools/shell` and `tools/vm`.

## CI (`.github/workflows/`)

| Workflow | Triggers | What it runs |
|---|---|---|
| `checks.yml` | push (all branches) + PR | Per-check `nix build '.#checks.x86_64-linux.<name>'` jobs for the eval checks (themes, secrets encryption, projects/ftp pipelines, eval of all configs) + nixfmt + shellfmt + `shell-rust-fmt` + `vm-tests` (`cargo fmt --check && cargo test --workspace --locked` via `nix develop .#vm`) |
| `nvim-tests.yml` | push + PR | Links `domains/editor/nvim/config` → `~/.config/nvim`, `nvim --headless '+Lazy! sync'`, then plenary adapter tests (`tests/adapters/init.lua`); lazy plugin cache keyed on `lazy-lock.json` |
| `secret-scan.yml` | push + PR | gitleaks-action (fetch-depth 0) + trufflehog (`--results=verified,unknown`) |
| `openwiki-update.yml` | daily cron + manual | Runs `openwiki code --update --print` (OpenRouter + LangSmith env) and opens a PR with `openwiki/`, `AGENTS.md`, `CLAUDE.md`, workflow changes |

Nix CI uses DeterminateSystems `nix-installer-action` + `magic-nix-cache-action`.

> CI gap: `home-theme-override-test` and `build-all` have dedicated jobs in `checks.yml`; `check-secrets-encrypted`, `check-ftp-encrypted`, and the three pipeline/declared checks run in the `eval-checks` matrix. Secret-hygiene regressions are additionally caught by gitleaks/trufflehog in `secret-scan.yml`. Functional `projects`/`ftp` checks use throwaway age keys — decryption keys never leave real hosts, so live FTP mounts remain a per-host runbook check.

## Git Hooks and Secret Hygiene

- Install: `just install-hooks` (sets `core.hooksPath githooks`).
- `githooks/pre-commit` — `gitleaks git --pre-commit --staged --redact` (host binary or `nix run nixpkgs#gitleaks`).
- `githooks/pre-push` — scans each pushed ref range with gitleaks (`<remote_oid>..<local_oid>`, or `--not --remotes` for brand-new refs).
- `.gitleaks.toml` allowlists age ciphertext and public keys, and excludes `README.md`/`pure.md`/`analysis.md`/`openwiki/`; a custom rule flags plaintext secrets inside `secrets.yaml` and `secrets/master/`.
- `*.dec`, `*.agekey`, `node_modules`, `result*`, `*.qcow2` are gitignored.
- See [Secrets](secrets.md) for the full scanning story.

## justfile Recipes

| Recipe | Action |
|---|---|
| `just bootstrap-secrets host=…` | `angst bootstrap-secrets --host <host>` |
| `just disko host=…` | Run disko with `hosts/<host>/disk.nix` |
| `just hardware host=…` | `nixos-generate-config --show-hardware-config > hosts/<host>/hardware.nix` |
| `just bootstrap-disk host=…` | `disko` + `hardware` |
| `just build host=…` | `nix build .#nixosConfigurations.<host>` |
| `just switch host=…` | `sudo nixos-rebuild switch --flake .#<host>` |
| `just hm host=… user=joao` | Build home activation package |
| `just hm-switch host=… user=joao` | Build + `./result/activate` |
| `just analyze` | Regenerate `analysis.md` |
| `just check` | `nix flake check` |
| `just dev` | `nix develop` (default shell) |
| `just install-hooks` | Enable githooks |
| `just vm host=…` / `just vm-ssh host=…` | VM start / ssh via `tools/vm#wrapped` |

## VM Workflow

The VM is the fastest way to test changes without touching a real machine; the host repo is live-mounted so edits inside the guest hit the host tree (and vice versa).

```bash
nix run .#vm -- --headless          # or: just vm; add DISPLAY for gtk UI
nix run .#vm -- ssh                 # connect (port 2222, shared-key auth)
nix run .#vm -- status / health     # verify QEMU + port + SSH
nix run .#vm -- mcp start           # expose MCP server for AI agents (port 8765)
```

Inside the VM: `~/.config/angst` is symlinked to the host repo (`modules/vm/host-mount.nix`), the host age keys are injected via `/tmp/shared` (`vm-age-key`), inbound SSH auth is the declarative `authorized_keys` baked from `secrets/ssh/*.pub`, and `/persist` keeps `.config/age`, `.secrets`, `.ssh`, and configured home dirs. Use `angst watch` on the host to hot-reload configs into both machines.

VM gotchas:
- `vm start` refuses to run if the target host's decl doesn't include the `vm` profile (`ensure_vm_profile`).
- First boot builds the VM from the flake (can take a while); subsequent boots are fast.
- If SSH hangs, check `vm health`; stale QEMU processes are killed automatically on `start`.

## Machine Lifecycle (runbook)

**New machine (NixOS):**

```bash
mkdir -p hosts/<domain>/<hostname>
cat > hosts/<domain>/<hostname>/default.nix <<'EOF'
{ type = "nixos"; system = "x86_64-linux"; hostname = "<hostname>"; username = "joao";
  theme = "miasma"; profiles = ["base" "desktop" "development"]; toolchains = "*"; }
EOF
just hardware host=<hostname>        # generate hardware.nix next to the decl
just bootstrap-secrets host=<hostname>   # create encrypted secrets.yaml + password hash
just switch host=<hostname>          # deploy
```

**Home-only machine (e.g. `personal/mint`, `type = "home"`):** create the decl, then `just hm-switch host=<hostname>` — no NixOS rebuild needed; secrets optional.

**Recovery / unseeded boot:** without an age key the host builds and boots with the fallback password hash (default "changeme" from `lib/resolve.nix`); run `angst bootstrap-master-password --host <host>` and re-switch once the key is present at `~/.config/age/keys.txt`.

**Maintenance:** `nix flake lock`/`nix flake update` for inputs; `nix-collect-garbage -d` after switches; `just analyze` to refresh `analysis.md`.
