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
- **Opaque folder IDs** (`openssl rand -hex 8`, 16 chars / 64 bits, not
  name-derived and not brute-forceable) — real names live only inside encrypted
  files. Everything stays in the one repo.
- Cloned projects land under **`~/projects/`** by default (0755), keeping the
  generated-project parent distinct from the angst `repoPath` (`proj/angst`,
  unchanged). Default on-disk dir = `projects/<name>`.
- **Clones are never modified for leak prevention.** Cloned repos under
  `~/projects/` get no hooks, no `core.hooksPath`, and no `.gitignore` edits —
  secret-leak detection happens only in the angst repo (`githooks/`,
  `checks/secrets.nix`, gitleaks CI, and the projects-scoped gitleaks rule).
  The only file the tool writes into a clone is the decrypted `.env`.
- **Scope-based age keys**: `personal` and `work` projects use *different*
  sops age keys (cryptographic separation). Work files list only the work key
  as recipient, so a company-side/work-key compromise can never decrypt
  personal secrets, and the two scopes rotate independently.
- **Single shared work key across hosts**: generated **once** (first host via
  `init-work`), copied to every host through the existing `.config/sops`
  impermanence dir. `init-work` refuses to overwrite an existing key. This makes
  the cross-host store decryptable everywhere and keeps `rekey work` a
  one-key rotation.

## Storage layout

```
projects/
├── personal/               # encrypted to the PERSONAL age key only
│   └── 3f9a1c2b4d7e09a2/   # opaque id (openssl rand -hex 8)
│       ├── metadata.yaml   # sops BINARY: plaintext JSON {name,repo,branch?,dir?,deps?,scope}, byte-exact
│       └── env             # sops BINARY: whole .env, byte-exact
└── work/                   # encrypted to the WORK age key ONLY — never personal
    └── 7b2d4e88a3c05f11/
        ├── metadata.yaml
        └── env
```

- Projects are discovered by globbing `projects/{personal,work}/*/metadata.yaml`.
  No central file. Add/remove project = add/remove folder.
- Cloned dirs under `~/projects/` use the **decrypted real name**
  (`~/projects/<name>`, or the `--dir` metadata override) — never the opaque id.
  The opaque id exists only inside the angst repo's `projects/` store.
- **Both** `metadata.yaml` and `env` are encrypted with sops **binary** format:
  the entire plaintext is one opaque blob — real names, URLs, structure, and even
  which fields exist never appear in cleartext. Plaintext metadata is JSON
  (parsed with `jq` after `sops -d --input-type binary --output-type binary`).
- `.sops.yaml` rules:
  - `projects/personal/.*$` → personal age public key,
  - `projects/work/.*$` → work age public key (the personal key is **never**
    listed as a recipient for work files).
- The `scope` sub-store is visible; opaque ids still hide *which* projects.
- Plaintext metadata carries a `scope` field (`"personal" | "work"`), validated
  against the folder path after decryption.

## New domain: `domains/git/projects/`

- `default.nix`: `{ package = "git"; customXdg = true; description = "Automatically sync declared dev projects"; }` (passes `mkDomain`).
- `home.nix`: an `angst-projects-sync` tool built with `pkgs.writeShellApplication`
  whose `text` sources the shared `scripts/angst-projects.sh` sync logic
  (runtimeInputs: `git sops jq openssl coreutils diffutils findutils`), wired as:
  - a home activation entry, and
  - a `systemd.user` oneshot `angst-projects-sync`
    (`After = network-online.target`, `Wants = network-online.target`).
- The store is located via `repoPath` (specialArg already available to `home.nix`):
  `$HOME/<repoPath>/projects`. The CLI locates it with the existing
  `repo_root_default()` (`git rev-parse --show-toplevel`).
- The tool self-decrypts with sops. Scope is derived from the store path
  (`projects/personal/…` vs `projects/work/…`) and the matching key file is
  selected per project via `SOPS_AGE_KEY_FILE`:
  - personal → default key (`~/.config/sops/age/keys.txt` / `SOPS_AGE_KEY`),
  - work → `~/.config/sops/age/work-keys.txt` (0600, `SOPS_WORK_AGE_KEY_FILE`
    override).
- **Nothing fails a build or boot**: a missing key for a scope, a missing repo,
  no network, or any decrypt error → skip those projects with a warning and
  **exit 0**. Project metadata never enters Nix eval.
- **No hooks, no config changes in clones.** The tool never touches
  `core.hooksPath` or `.gitignore` inside a clone.

### Sync semantics (per registry project)

1. `mkdir -p` parent root (`~/projects`, 0755).
2. `<dir> = ~/projects/<decrypted-name>` (from metadata; the `--dir` field
   overrides). `[ -d <dir>/.git ] || git clone [--branch <b>] <repo> <dir>` —
   no auto-pull, no hooks installed.
3. Run `deps` only on a fresh clone (re-run via `angst projects sync`).
4. Env, hash-tracked via sidecar `~/.secrets/projects/<name>.env.sha256`:
   - `.env` missing → materialize store → `.env` (0600),
   - `.env` unchanged since last materialize → refresh if the store changed,
   - `.env` locally edited → **never clobber**; mark `stale`, print diff,
     exit non-zero.

### Secret leak prevention (defense in depth)

Clones are never modified for leak prevention (no hooks, no `core.hooksPath`,
no `.gitignore` edits) — all detection happens in the angst repo:

1. **Store hygiene**: `capture` / `edit-env` write plaintext only to temp files
   *outside* the repo (`/tmp` or `~/.secrets/projects/.tmp`), then re-encrypt in
   place — plaintext never lands inside `projects/`.
2. `sync` / `status` never print decrypted env values (only key names / redacted
   diffs).
3. Flake checks (`checks/secrets.nix`) assert every `projects/**/metadata.yaml`
   and `projects/**/env` contains the `sops:` / `ENC[AES256_GCM` block **and**
   no plaintext `name:` / `repo:` / URL / secret content anywhere in the file
   (guaranteed by binary encryption; the check is a regression guard).
4. `.gitleaks.toml` adds a **projects-scoped rule** that flags plaintext
   secret-like values under `projects/` (like the existing
   `angst-plaintext-secret-value` rule). No broad path allowlist on `projects/`
   — the existing global `ENC[AES256_GCM,` regex already lets ciphertext
   through, so a tree-wide allowlist is neither needed nor wanted.

## CLI (`scripts/angst.sh`)

All commands take the real name and resolve the opaque id by decrypting
metadata (both scopes; names must be unique across the whole store — `add`
rejects duplicates). Sync logic lives in `scripts/angst-projects.sh`, shared by
the CLI and the home-manager wrapper.

- `angst projects add <name> <repo> [--dir PATH] [--branch B] [--deps CMD] [--scope work|personal]`
  — create random-id folder + encrypted metadata (default scope: personal);
  errors if the name already exists in the store
- `angst projects init-work` — generate the shared work age keypair **once**
  (`~/.config/sops/age/work-keys.txt`, 0600); refuses if the key already exists,
  prints the public key and instructs adding it to the `.sops.yaml` work rule
  and copying the key to every other host. The key is never committed and
  persists via the existing `.config/sops` impermanence dir
- `angst projects sync` — run the sync logic (no dependency on a
  home-installed binary; the CLI and the systemd service share the same code)
- `angst projects status` — table of projects (incl. scope); flags stale env;
  diffs each repo's `.env.example` to surface upstream-added vars
- `angst projects capture <name>` — encrypt current `<dir>/.env` → store
  (the edit → capture → commit loop)
- `angst projects edit-env <name>` — decrypt store → `$EDITOR` → re-encrypt
  (binary) → resync if in sync
- `angst projects rm <name>` — remove the folder
- `angst projects rekey work` — leak response: generate a new work key, add its
  public key to the `.sops.yaml` work rule, run `sops updatekeys` on all work
  files (re-encrypts to new+old), then **remove the old public key** from
  `.sops.yaml` and run `sops updatekeys` a second time to strip it from the
  files; distribute the new `work-keys.txt` to every host. The personal store
  is never touched.

## Supporting changes

| File | Change |
|---|---|
| `scripts/angst-projects.sh` | new: shared `projects` command logic (add/init-work/sync/status/capture/edit-env/rm/rekey) |
| `scripts/angst.sh` | add `projects) angst_projects_cmd "$@" ;;` case |
| `lib/flake/context.nix` | add `../../scripts/angst-projects.sh` to the `angstTool` concat list; add `sops age openssl diffutils` to its runtimeInputs |
| `modules/vm/vm-profile.nix` | add `../../scripts/angst-projects.sh` to the VM `angstCli` concat list; same runtimeInputs additions |
| `lib/resolve.nix` | default `projects = { persistDirs = ["projects"]; } // (decl.projects or {})` |
| `lib/build/mkNixos.nix` | append `host.projects.persistDirs` to the impermanence dirs (alongside `secrets.persistDirs`) |
| `.sops.yaml` | rules `projects/personal/.*$` → personal age key, `projects/work/.*$` → work age key (personal key never a work recipient) |
| `checks/secrets.nix` | also scan `projects/**/metadata.yaml` and `projects/**/env`: require `sops:` / `ENC[AES256_GCM` and no plaintext `name:` / `repo:` / URL / secret content anywhere in the file |
| `.gitleaks.toml` | add a `projects/.*` rule flagging plaintext secret-like values (no path allowlist) |
| `profiles/development.nix` | add `"git.projects"` |
| `hosts/{personal/nixos,vm}/default.nix` | `projects.persistDirs = ["projects"]` (explicit; the `resolve.nix` default already covers it, kept for readability) |
| `domains/agents/opencode/` | **no change** — no host-level access restrictions |
| openwiki `domains`/`secrets`/`quickstart` + `README.md` | document the domain, sops flow, CLI usage |

## Verification

1. `nix flake check`
2. `nix build .#homeConfigurations.joao`
3. Manual:
   - `angst projects add` a test project (duplicate name rejected)
   - `angst projects sync` → clone-if-missing works
   - edit `.env` → `angst projects capture` → byte-identical round-trip
   - edit `.env` locally again → `stale` fires, no clobber
   - confirm `projects/` tree shows only opaque ids; `grep name: projects/**` is empty
   - confirm cloned repos have **no** hooks and no `.gitignore` edits
     (`git -C <dir> config --get core.hooksPath` is empty), and clone dirs are
     named after the decrypted project names
   - `angst projects init-work` refuses on second run; add a `--scope work`
     project → syncs under the work key; `sops -d` with the wrong key file fails
     for that scope; `rekey work` re-encrypts the work store and leaves personal
     untouched
   - `angst projects sync` with the network down / work key removed → warns,
     exits 0
