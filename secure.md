# Secret management security review

Assessment of the sops-nix + age secret model, captured from a read-through of
`modules/secrets.nix`, `checks/secrets.nix`, `runtime/`, `domains/remote/ssh/`,
`tools/vm/crates/vm-core/src/shared.rs`, and `.sops.yaml`.

## Verdict

The model is fundamentally sound: **sops-nix + age**, secrets never committed in
plaintext, runtime decryption to `~/.secrets/` at `0600`, and real defense-in-depth
(gitleaks pre-commit/pre-push + CI gitleaks/trufflehog + 5 flake checks verifying
sops/age envelopes). Age keys on disk are correctly `0600`. Scope isolation
(personal vs work keys) is a genuinely good blast-radius control.

## Weaknesses (ranked)

1. **Weak password KDF — `mkpasswd -m sha-512`**
   (`runtime/bootstrap-secrets.nix:19`, `runtime/angst-cli.nix:137`).
   SHA-512 crypt is fast and GPU-crackable; NixOS default is yescrypt. The same
   hash is applied to both `root` and the user, and `check-password`
   (`checks/password.nix:8`) plus the `resolve.nix:59` fallback are hardcoded to
   the `$6$...` format.

2. **`angst-bootstrap-secrets` is unsandboxed and leaks the hash**
   (`lib/build/mkNixos.nix:105`, `runtime/bootstrap-secrets.nix`).
   `usermod -p "$HASH"` puts the password hash in argv (briefly visible to other
   processes via `ps`/`/proc`), and unlike `angst-provision-ssh-key` it has no
   `NoNewPrivileges`/`PrivateTmp`/`ProtectSystem` hardening. Prefer `chpasswd`
   (reads from stdin) + sandboxing.

3. **Passphraseless shared SSH keys** (`secrets/ssh/*.age`) — one host filesystem
   compromise exposes that scope's identity everywhere it is authorized.
   Documented trade, but the largest real-world risk.

4. **Build-time `canDecrypt` gating** (`modules/secrets.nix:32`) — whether sops
   wiring lands in the output depends on eval env (`HOME` + key presence).
   Non-reproducible builds; a build on a keyless machine (CI) silently drops
   secret wiring. Footgun, not a direct vuln.

5. **VM age-key forwarding** (`tools/vm/crates/vm-core/src/shared.rs`) — private
   age keys are copied to `~/.local/state/vm/keys/<host>` and into guest
   `/tmp/shared`. A second on-disk plaintext copy; guest-side perms of the shared
   mount are worth verifying.

6. **TOFU `StrictHostKeyChecking=accept-new`** on project clones — first-connect
   MITM window (documented).

7. **FTP rclone config now rests plaintext** at `~/.secrets/ftp/*.conf` (0600)
   rather than tmpfs-only — documented trade in `secret.md`.

## No findings (verified clean)

- `secrets.yaml` files are fully sops-encrypted (age + MAC + `sops:` block).
- `.age` files carry valid `age-encryption.org/v1` envelopes; `.pub`s are valid.
- No committed password hash (hosts use runtime bootstrap; only the `changeme`
  fallback hash lives in `resolve.nix`).
- Age keys on disk are `0600`; `.gitignore` covers `*.dec`/`*.agekey`.
