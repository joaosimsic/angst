# Secrets unification plan

Unify all secrets into `~/.secrets/`. Remove the separate `~/secrets/` tree.
The work-key ftp config is decrypted into `~/.secrets/angst/<name>.conf` (0600) at
home activation — exactly like `opencode-go-key` — using the host's work key.
No re-encryption; the repo file stays work-key-only.

Design principle: **all hosts must be able to use the work key; the only
exception is that work-only hosts should not use the personal key.**

## Part A — Folder unification

### A1. New `runtime/ftp-secrets-home.nix`
Pattern: `ssh-key-provision.nix`.

- For each ftp mount, decrypt `flakeSelf/secrets/ftp/...age` ->
  `$HOME/.secrets/angst/<name>.conf` using
  `sops -d --input-type binary` with
  `SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/work-keys.txt`, then `chmod 600`.
- Ensures `~/.secrets` and `~/.secrets/angst` exist (700).
- Warns + skips if the work key is missing (same graceful behavior as today's mount script).
- `runtimeInputs`: sops, age, coreutils.

### A2. `runtime/default.nix`
Register `ftpSecretsHome` (let-block + inherit list, alongside `ftpMount`).

### A3. `domains/remote/ftp/home.nix`
- Delete the `home.file` block and `installPath` (the mechanism that creates `~/secrets/`).
- Add
  `home.activation.angstFtpSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] '<decrypt>.bin'`
  for all configured mounts.
- `ensureFtpMountDirs`: keep mkdir of mountPoints; add
  `rmdir "$HOME/secrets/angst" "$HOME/secrets" 2>/dev/null || true`
  to remove the stale tree after switch.
- Mount service receives `configFile = ".secrets/angst/<name>.conf"` (plaintext).

### A4. `runtime/ftp-mount.nix`
- Read `$HOME/.secrets/angst/<name>.conf` directly.
- Drop the `sops -d` step and the work-key existence check (decryption happens at activation).
- Keep the JSON -> rclone INI transform into the tmp file.
- Drop `sops`/`age` from `runtimeInputs` (keep rclone, jq, coreutils).

## Part B — Work key available on all hosts

### B1. Make the work key a default, not an opt-in
- `modules/vm/vm-profile.nix`: default `injectWorkAgeKey` to enabled (or remove the
  option) so the vm always gets `work-keys.txt`.
- Drop the `hosts/vm/default.nix` `angst.vm.injectWorkAgeKey = true` finagling and the
  "work-scoped secrets" framing comment.
- `ssh-provision-home.nix` (non-nixos) and `system.nix` systemd service (nixos) already
  provision both scopes on all current hosts (base profile enables `remote.ssh`), so the
  work key is provisioned everywhere.

### B2. Personal key only on personal hosts
- No current host changes (mint/nixos/vm are all personal hosts and keep `keys.txt`).
- The scope-based `provision_scope personal|work` design already allows a future
  work-only host to provision only the work scope. Do not add personal-key provisioning
  to any host-agnostic path.

## Not changing
- `modules/secrets.nix` + `modules/home/secrets-activation.nix` (personal sops flow,
  already writes into the same `~/.secrets/`).
- `checks/secrets.nix` `ftpCheck` (repo file stays work-key-encrypted -> passes).
- `.sops.yaml` `secrets/ftp/.*` -> work key only (decryptable on any host holding the work key).

## Bootstrap note
`~/.config/sops/age/work-keys.txt` must exist on each host (like `keys.txt` today).
- mint: already present.
- vm: gets it via `/tmp/shared`.
- personal nixos host: needs it copied in once (same manual bootstrap as the personal key).

## Verification
- `nix flake check`.
- Build the mint home config to confirm evaluation.
- After switch on mint: `~/secrets` gone; `~/.secrets/angst/ftp-server.conf` (0600)
  exists; `systemctl --user start angst-ftp-ftp-server` still mounts.

## Risk
Plaintext rclone config now rests at `~/.secrets/angst/ftp-server.conf` (0600, dir 700)
instead of only existing in tmpfs during mount — intended, matching how other secrets are handled.
