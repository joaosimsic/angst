# Plan: `projects` — auto-synced, encrypted, single-place project manager

Declare dev projects (GitHub/GitLab) once, get them cloned on every host, with
persisted deps and `.env` handling that survives a public repository.

## Decisions (locked)

- The angst repo (`git@github.com:joaosimsic/angst.git`) is **public**. All
  project metadata (names, URLs, `.env`) must be **encrypted** — nothing about
  private/company repos may appear in tracked files, **including directory names**.
- **No host-level isolation.** On the host, every app (opencode, editors,
  tooling) accesses project repos and `.env` normally. The only constraint is
  the public repo. (opencode's built-in `.env` read-deny is its own default and
  stays.)
- Clone **if missing only** — no auto-pull; updates happen when you work in the
  repo. Persistence guarantees no re-clone/re-download.
- **Full `.env` per project**, encrypted with sops in **binary format**
  (byte-exact round-trip: comments, quoting, blank lines all preserved).
  Two-way sync so the encrypted store can't silently go stale.
- Shared `projects/` at the repo root — one store for all hosts.
- **Opaque folder IDs** (`openssl rand -hex 4`, not name-derived, not
  brute-forceable) — real names live only inside encrypted `metadata.yaml`.
  Everything stays in the one repo.
- Cloned projects land under **`~/projects/`** by default (0755), keeping the
  generated-project parent distinct from the angst `repoPath` (`proj/angst`,
  unchanged). Default on-disk dir = `projects/<name>`.
- **Per-project git hooks** prevent secret leaks from cloned repos (same
  per-repo `core.hooksPath` mechanism the angst repo itself uses — no global
  side effects).

## Storage layout

```
projects/
├── 3f9a1c2b/                # opaque id
│   ├── metadata.yaml        # sops YAML: name, repo, branch?, dir?, deps?   (encrypted)
│   └── env                  # sops binary: whole .env, byte-exact            (encrypted)
└── 7b2d4e88/
    ├── metadata.yaml
    └── env
```

- Projects are discovered by globbing `projects/*/metadata.yaml`. No central
  file. Add/remove project = add/remove folder.
- Real names, URLs, on-disk paths exist **only** inside encrypted files.
- `.sops.yaml` rule `projects/.*$` with the personal age key.

## New domain: `domains/git/projects/`

- `default.nix`: `{ package = "git"; customXdg = true; description = "Automatically sync declared dev projects"; }` (passes `mkDomain`).
- `home.nix`: an `angst-projects-sync` tool (`pkgs.writeShellApplication`;
  runtimeInputs: `git sops jq openssh coreutils diffutils findutils`), wired as:
  - a home activation entry, and
  - a `systemd.user` oneshot `angst-projects-sync`
    (`After = sops-nix.service network-online.target`, `Wants = network-online.target`).
- The tool self-decrypts with the age key at `~/.config/sops/age/keys.txt`;
  missing key → warn and exit 0 (builds/boots never fail). Project metadata
  never enters Nix eval.
- The tool also installs **per-project git hooks**: after a fresh clone it runs
  `git -C <dir> config core.hooksPath <hooks-dir>`, pointing at a managed hook
  directory shipped by the domain (e.g. `~/.local/share/angst/project-hooks`).
  Per-repo config → no global side effects and no clash with the angst repo's
  own `core.hooksPath = githooks`. Hook content is generated at build time.
  - `pre-commit`:
    1. blocks staged secret-like files, aborting with an offender list:
       `**/.env`, `**/.env.*` (`.env.example` allowed), `*.dec`, `*.agekey`,
       `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `*.p12`, `*.pfx`;
    2. runs `gitleaks git --pre-commit --staged --redact`, falling back to
       `nix run --quiet nixpkgs#gitleaks --` when gitleaks isn't on PATH
       (same pattern as the repo's own `githooks/pre-commit`).
  - `pre-push`: runs gitleaks on the pushed range (same pattern as the repo's
    `githooks/pre-push`).

### Sync semantics (per registry project)

1. `mkdir -p` parent root (`~/projects`, 0755).
2. `[ -d <dir>/.git ] || git clone [--branch <b>] <repo> <dir>` — no auto-pull;
   after a fresh clone, install the project git hooks (see above).
3. Run `deps` only on a fresh clone (re-run via `angst projects sync`).
4. Env, hash-tracked via sidecar `~/.secrets/projects/<name>.env.sha256`:
   - `.env` missing → materialize store → `.env` (0600),
   - `.env` unchanged since last materialize → refresh if the store changed,
   - `.env` locally edited → **never clobber**; mark `stale`, print diff,
     exit non-zero.
5. If not already ignored, append `.env` / `.env.*` to `<dir>/.gitignore`
   (keeping `.env.example` tracked).

### Secret leak prevention (defense in depth)

1. `.gitignore` guard at clone time (step 5 above).
2. Per-project git hooks block secret-like files and run gitleaks
   (`pre-commit` + `pre-push`, see the domain section).
3. **Store hygiene**: `capture` / `edit-env` write plaintext only to temp files
   *outside* the repo (`/tmp` or `~/.secrets/projects/.tmp`), then re-encrypt in
   place — plaintext never lands inside `projects/`.
4. `sync` / `status` never print decrypted env values (only key names / redacted
   diffs).
5. Flake checks (`checks/secrets.nix`) assert `projects/**/metadata.yaml` and
   `projects/**/env` contain the `sops:` / `ENC[AES256_GCM` block **and** no
   plaintext `name:` / `repo:` / URL content outside it; `.gitleaks.toml`
   allowlists the encrypted tree while still flagging plaintext.

## CLI (`scripts/angst.sh`)

All commands take the real name and resolve the opaque id by decrypting metadata:

- `angst projects add <name> <repo> [--dir PATH] [--branch B] [--deps CMD]`
  — create random-id folder + encrypted metadata
- `angst projects sync` — run the sync tool
- `angst projects status` — table of projects; flags stale env; diffs each
  repo's `.env.example` to surface upstream-added vars
- `angst projects capture <name>` — encrypt current `<dir>/.env` → store
  (the edit → capture → commit loop)
- `angst projects edit-env <name>` — decrypt store → `$EDITOR` → re-encrypt
  (binary) → resync if in sync
- `angst projects rm <name>` — remove the folder

## Supporting changes

| File | Change |
|---|---|
| `lib/resolve.nix` | default `projects = { persistDirs = ["projects"]; } // (decl.projects or {})` |
| `lib/build/mkNixos.nix` | append `host.projects.persistDirs` to the impermanence dirs (like `secrets.persistDirs`) |
| `.sops.yaml` | rule `projects/.*$` with the personal age key |
| `checks/secrets.nix` | require `sops:` / `ENC[AES256_GCM` in `projects/**/metadata.yaml` and `projects/**/env`, and no plaintext `name:`/`repo:`/URL outside the sops block |
| `.gitleaks.toml` | allowlist `projects/` ciphertext (flag any plaintext secrets) |
| `profiles/development.nix` | add `"git.projects"` |
| `hosts/*/default.nix` | `projects.persistDirs = ["projects"]` on impermanence hosts (`nixos`, `vm`) |
| `domains/agents/opencode/` | **no change** — no host-level access restrictions |
| openwiki `domains`/`secrets`/`quickstart` + `README.md` | document the domain, sops flow, CLI usage |

## Verification

1. `nix flake check`
2. `nix build .#homeConfigurations.joao`
3. Manual:
   - `angst projects add` a test project
   - `angst projects sync` → clone-if-missing works
   - edit `.env` → `angst projects capture` → byte-identical round-trip
   - edit `.env` locally again → `stale` fires, no clobber
   - confirm `projects/` tree shows only opaque ids
   - `git -C <dir> config core.hooksPath` points at the managed hooks dir;
     staging `.env` / a fake key is blocked, gitleaks runs on commit/push
