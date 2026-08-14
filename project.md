# Plan: `projects` — auto-synced, encrypted, single-place project manager

Declare dev projects (GitHub/GitLab) once, get them cloned on every host, with
`.env` handling that survives a public repository.

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
  (byte-exact round-trip: comments, quoting, blank lines all preserved) in the
  repo store. `export` re-encrypts the working store into the repo store.
- **Three layers** — a committed **repo store** (`projects/`, sops-encrypted
  transport: travels with the public repo so new machines can clone projects),
  a **working store** at the fixed per-host path `~/.secrets/projects`
  (decrypted plaintext; runtime ops read/write it directly, no `repoPath`), and
  clones at `~/projects` (divergent per host). The repo store is written **only
  by `angst projects export`** (then commit); the working store is seeded from
  the repo store at build time via `import`.
- **Hosts select by opaque id, never by name.** Each host decl's `projects = [...]`
  lists the opaque store ids it wants synced (ids are already public folder names,
  not name-derived). An empty list syncs and persists nothing. The wrapper filters on
  `ANGST_PROJECTS_ONLY` (unset = manual CLI syncs all). Works on **both** `nixos` and
  `home`-only hosts via a `projects` specialArg.
- **Opaque folder IDs** (`openssl rand -hex 8`, 16 chars / 64 bits, not
  name-derived and not brute-forceable) — real names live only inside the
  encrypted repo store.
- Cloned projects land under **`~/projects/`** by default (0755). Default on-disk
  dir = `projects/<name>`.
- **Clones are never modified for leak prevention.** Cloned repos under
  `~/projects/` get no hooks, no `core.hooksPath`, and no `.gitignore` edits.
  The only file the tool writes into a clone is the decrypted `.env`.
- **Scope-based age keys**: `personal` and `work` projects use *different*
  sops age keys (cryptographic separation). Work files list only the work key
  as recipient, so a company-side/work-key compromise can never decrypt
  personal secrets. Both keys are **static** — generated once, provisioned on
  every host, never rotated by this tool.
- **Single shared work key across hosts**: generated **once, out-of-band**
  (manual `age-keygen`), copied to every host through the existing `.config/sops`
  impermanence dir. The key is **static** — this tool never generates, rotates,
  or overwrites it; a missing work key means misprovisioning, not a bootstrap
  case. This makes the cross-host store decryptable everywhere.

## Storage layout

```
# repo store (committed, ENCRYPTED transport)
projects/
├── personal/
│   └── 3f9a1c2b4d7e09a2/
│       ├── metadata.yaml   # sops BINARY of {name,repo}
│       └── env             # sops BINARY of the whole .env
└── work/
    └── 7b2d4e88a3c05f11/
        ├── metadata.yaml
        └── env

# working store (per-host, DECRYPTED plaintext)
~/.secrets/projects/
├── personal/
│   └── 3f9a1c2b4d7e09a2/
│       ├── metadata.yaml   # plaintext JSON {name,repo}
│       └── env             # plaintext .env
└── work/
    └── 7b2d4e88a3c05f11/
        ├── metadata.yaml
        └── env

# clone root (per-host, divergent)
~/projects/<name>/.git + .env
```

- Repo-store projects are discovered by globbing `projects/{personal,work}/*/metadata.yaml`;
  working-store by globbing `~/.secrets/projects/{personal,work}/*/metadata.yaml`.
  No central file. Add/remove project = add/remove folder.
- The repo store is written **only by `angst projects export`** (encrypt working →
  repo) and read by `import`/the build seed (decrypt repo → working). Every other
  op works on the decrypted working store.
- Cloned dirs under `~/projects/` use the **decrypted real name**
  (`~/projects/<name>`) — never the opaque id. The opaque id exists only inside
  the stores.
- Repo-store `metadata.yaml` and `env` are sops **binary** encrypted: the entire
  plaintext is one opaque blob — real names, URLs, structure, and even which
  fields exist never appear in cleartext. Working-store files are plaintext
  (private, 0700); plaintext metadata is JSON (parsed with `jq`).
- The per-scope recipient is derived from the scope key file at import/export
  time (no repo `.sops.yaml` routing): personal → personal age public key,
  work → work age public key (the personal key is **never** listed as a
  recipient for work files).
- The `scope` sub-store is visible; opaque ids still hide *which* projects. The
  scope of a project is its folder path (`personal/…` vs `work/…`) — metadata
  carries no `scope` field to disagree with it.

## New domain: `domains/git/projects/`

- `default.nix`: `{ package = "git"; customXdg = true; description = "Automatically sync declared dev projects"; }` (passes `mkDomain`).
- `home.nix`: an `angst-projects-sync` tool built with `pkgs.writeShellApplication`
  whose `text` sources the shared `runtime/angst-projects.sh` sync logic
  (runtimeInputs: `git sops age jq openssl coreutils diffutils findutils`), wired as:
  - a home activation entry (`import` then `sync`), and
  - a `systemd.user` oneshot `angst-projects-sync`
    (`After = network-online.target`, `Wants = network-online.target`,
    ExecStart = `import; sync`).
  The wrapper bakes `ANGST_PROJECTS_ONLY` from the host's declared `projects` ids
  and `ANGST_PROJECTS_REPO=${flakeSelf}/projects` as the build-time seed source
  (a `projects` specialArg is threaded through home-manager on both `nixos` and
  `home` hosts), so only host-selected projects sync.
- The working store lives at the fixed per-host path `~/.secrets/projects`
  (decrypted plaintext; `ANGST_PROJECTS_STORE` overrides). The repo store is
  `projects/` in the repo (`ANGST_PROJECTS_REPO` overrides; the CLI resolves it
  via git discovery).
- `import`/`export`/seed use sops. Scope is derived from the store path
  (`personal/…` vs `work/…`) and the matching key file is selected per project
  via `SOPS_AGE_KEY_FILE`:
  - personal → default key (`~/.config/sops/age/keys.txt` / `SOPS_AGE_KEY`),
  - work → `~/.config/sops/age/work-keys.txt` (0600, `SOPS_WORK_AGE_KEY_FILE`
    override).
- **Nothing fails a build or boot**: a missing key for a scope, a missing repo,
  no network, or any decrypt error → skip those projects with a warning and
  **exit 0**. Project metadata never enters Nix eval.
- **No hooks, no config changes in clones.** The tool never touches
  `core.hooksPath` or `.gitignore` inside a clone.

### Sync semantics (per registry project)

0. Only projects whose opaque id is in the host's declared `projects` list are
   processed (`ANGST_PROJECTS_ONLY`, set-but-empty = none; unset = manual CLI
   syncs everything).
1. `mkdir -p` parent root (`~/projects`, 0755).
2. `<dir> = ~/projects/<name>` (from metadata). `[ -d <dir>/.git ] ||
   git clone <repo> <dir>` — no auto-pull, no hooks installed.
3. Env, hash-tracked via sidecar `~/.secrets/projects/<name>.env.sha256`:
   - `.env` missing → materialize store → `.env` (0600),
   - `.env` unchanged since last materialize → refresh if the store changed,
   - `.env` locally edited → **never clobber**; mark `stale`, print diff,
     exit non-zero.

### Secret leak prevention (defense in depth)

Clones are never modified for leak prevention (no hooks, no `core.hooksPath`,
no `.gitignore` edits) — all detection happens in the angst repo:

1. **Store hygiene**: the **repo store** is always sops-binary encrypted
   (`export` writes ciphertext only); the **working store** is private plaintext
   at `~/.secrets` (0700). Plaintext never lands inside the repo store.
2. `sync` / `status` never print decrypted env values (only key names / redacted
   diffs).
3. **Repo-side checks**: `check-projects-encrypted` asserts every committed
   `projects/**/metadata.yaml` + `env` is sops-encrypted with no plaintext
   name/repo/URL content, and gitleaks flags plaintext secret-like values under
   `projects/`. Clones under `~/projects/<name>` are *expected* to hold the
   decrypted `.env` (0600), since that is the sync output.

## CLI (`scripts/angst.sh`)

All commands take the real name and resolve the opaque id within the working
store (both scopes; names must be unique across the whole store — `add`
rejects duplicates). Sync logic lives in `runtime/angst-projects.sh`, shared by
the CLI and the home-manager wrapper.

- `angst projects add <name> <repo> [--scope work|personal]`
  — create random-id folder + plaintext metadata in the working store (default
  scope: personal); errors if the name already exists in the store. Then
  `angst projects export` pushes it to the repo store.
- `angst projects sync` — run the sync logic (no dependency on a
  home-installed binary; the CLI and the systemd service share the same code)
- `angst projects status` — table of projects (incl. scope); flags stale env;
  diffs each repo's `.env.example` to surface upstream-added vars
- `angst projects capture <name>` — copy current `<dir>/.env` → working store
  (the edit → capture → export loop)
- `angst projects edit-env <name>` — edit working-store env → `$EDITOR` →
  resync if in sync (then `export` to share)
- `angst projects import [--all]` — decrypt repo store → working store (seed);
  only missing entries unless `--all`
- `angst projects export [--all]` — encrypt working store → repo store (the
  **only** writer of the repo store); remember to commit
- `angst projects rm <name>` — remove from working store + repo store + sidecar

## Supporting changes

| File | Change |
|---|---|
| `runtime/angst-projects.sh` | shared `projects` command logic (add/sync/status/capture/edit-env/import/export/rm); working store at `~/.secrets/projects` (plaintext), repo store at `<repo>/projects` (encrypted); `sync` filters store ids against `ANGST_PROJECTS_ONLY` |
| `runtime/angst-cli.nix` | `projects) angst_projects_cmd "$@" ;;` case (already wired) |
| `lib/flake/context.nix` | add `runtime/angst-projects.sh` to the `angstTool` concat list; add `sops age openssl diffutils` to its runtimeInputs |
| `modules/vm/vm-profile.nix` | add `runtime/angst-projects.sh` to the VM `angstCli` concat list; same runtimeInputs additions |
| `lib/resolve.nix` | default `projects = decl.projects or []` — the host's list of opaque store ids (no persist dir declared by hosts) |
| `lib/build/mkNixos.nix` | `persistDirs = secrets.persistDirs ++ lib.optionals (host.projects != []) ["projects"]` — the single derived persistence point (clone root); add `projects` to home-manager `extraSpecialArgs` |
| `lib/build/mkHome.nix` | add `projects` to home-manager `extraSpecialArgs` (makes the domain work on home-only hosts) |
| `domains/git/projects/home.nix` | bake `ANGST_PROJECTS_ONLY` from the `projects` specialArg + `ANGST_PROJECTS_REPO=${flakeSelf}/projects` into the wrapper text; activation `mkdir -p ~/.secrets/projects` then `import; sync` |
| `.sops.yaml` | `projects/personal/.*$` → personal key, `projects/work/.*$` → work key (guard the committed repo store) |
| `checks/secrets.nix` + `checks/default.nix` | `check-projects-encrypted`: every committed `projects/**/metadata.yaml` + `env` is sops-encrypted with no plaintext name/repo/URL content |
| `.gitleaks.toml` | `angst-projects-plaintext-secret-value` rule under `projects/.*` |
| `profiles/development.nix` | add `"git.projects"` |
| `hosts/{personal/nixos,vm,personal/mint}/default.nix` | `projects = [<opaque ids>]` — which projects each host syncs; names never appear in tracked files (empty lists until projects are added) |
| `domains/agents/opencode/` | **no change** — no host-level access restrictions |
| openwiki `domains`/`secrets`/`quickstart` + `README.md` | document the domain, sops flow, CLI usage |

## Verification

1. `nix flake check`
2. `nix build .#homeConfigurations.joao`
3. Manual:
   - `angst projects add` a test project (duplicate name rejected)
   - `angst projects export` → repo store is sops-encrypted
   - fresh working store + `angst projects import` → decrypted working store
   - `angst projects sync` → clone-if-missing works
   - edit `.env` → `angst projects capture` → byte-identical round-trip
   - edit `.env` locally again → `stale` fires, no clobber
   - confirm both store trees show only opaque ids; `grep name:` on the repo store is empty
   - `angst projects export` with the wrong key file fails for that scope
   - `angst projects sync` with the network down / work key removed → warns,
     exits 0
