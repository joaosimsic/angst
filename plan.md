# Plan: explicit host secret declarations and remote i3 streaming

## Status

Draft. No code changes applied.

## Goal

1. Replace secret-scope inference from `hosts/<domain>/` with an explicit per-host declaration.
2. Decouple passwords from hostnames: many password files, each host selects one.
3. Separate host infrastructure secrets from app secrets.
4. Keep Sunshine for remote access because the requirement is the same i3 desktop.
5. Make the home NixOS host auto-login to i3 so Sunshine works without a manual session.
6. Add the new NixOS work host as a Moonlight client over Tailscale.

## Non-goals

- Moonshine. It cannot attach to an existing i3 session; it starts apps in its own compositor.
- Multiple simultaneous login passwords per host. One selected password applies to the user and root.
- Public exposure of Sunshine. Access stays on Tailscale.
- Treating the secret declaration as cryptographic proof. It is policy plus automation.

---

## 1. Current architecture and failure modes

### Host resolution

`lib/resolve.nix` maps a host declaration to a `host` attrset.

Current behavior:

- `host.hostname` comes from `decl.hostname`.
- `host.domain` comes from the directory under `hosts/`.
- `host.scopes` is inferred:
  - `hosts/personal/*` -> `[ "personal" "work" ]`
  - `hosts/work/*` -> `[ "work" ]`
  - `hosts/vm` -> `[ "personal" "work" ]`
  - fallback -> `[ "work" ]`
- `host.secrets` is an unscoped app-secret slug list.

Problems:

- `work` means three different things: domain (`hosts/work/`), hostname (`hosts/personal/work`), and scope (`secrets/apps/work/`).
- `hosts/personal/work` and `hosts/work/home` are different machines. Directory structure decides their scopes, not an explicit declaration.
- `domains/remote/stream/system.nix` hardcodes `tailscale-auth-key-nixos.age`.
- `tailscale-auth-key-*` and `sunshine-credentials` live under `secrets/apps/personal/`, mixing host infrastructure with cross-host app secrets.
- `secrets/master/<hostname>.age` ties one password to one hostname.
- `domains/remote/ssh/system.nix` does not pass `hostScopes`; it tries both scopes.
- VPN provisioning hardcodes both scopes.
- `projects` and `db` import loops both scopes.
- `angst bootstrap-master-password` infers scope from `strings.Contains(configDir, "/work/")`.

### Runtime secret flow today

```text
hosts/<domain>/<name>/default.nix
  -> lib/resolve.nix
     -> host.scopes (inferred)
     -> host.secrets (unscoped slugs)
  -> mkNixos / mkHome specialArgs
     -> hostScopes, hostSecrets
     -> angst-bootstrap-secrets (boot password)
     -> app-secrets home activation
     -> SSH / VPN / projects / db provisioners
```

### Remote stream flow today

```text
domains/remote/stream
  -> system.nix: Sunshine + Tailscale, host-only assumptions
  -> home.nix: Moonlight when hostType != "nixos"
```

Sunshine runs as a user service bound to `graphical-session.target`. i3 starts that target from its config. Therefore Sunshine needs a logged-in i3 session.

---

## 2. Target architecture

### 2.1 Namespace rules

- Host identity is `hostname` only. Directories and domains do not select secrets.
- Scope is only `personal` or `work`.
- Host infrastructure secrets are keyed by hostname.
- Passwords are a shared pool, not keyed by hostname.
- App secrets are keyed by scope and slug.

```text
secrets/
  passwords/<scope>/<name>.age        password pool
  apps/<scope>/<slug>.age             cross-host app secrets
  hosts/<hostname>/<name>.age         host infrastructure secrets
  ssh/<scope>.ed25519.age             shared SSH keys
  projects/<scope>.tar.age            project store
  db/<scope>.tar.age                  DB store
  vpn/...                             VPN files
```

### 2.2 Host declaration

Replace the current `secrets = [ ... ]` list with:

```nix
secrets = {
  # Age identities this host may use. No inference from hosts/<domain>/.
  scopes = [ "personal" "work" ];

  # One selected password from the pool, applied to user and root.
  password = "personal/main";

  # Exact app secrets: secrets/apps/<scope>/<slug>.age -> ~/.secrets/<slug>
  apps = [
    "personal/opencode-go-key"
    "work/cursor-api-key"
  ];

  # Exact host secrets: secrets/hosts/<hostname>/<name>.age
  # -> /run/angst/host-secrets/<name> on NixOS, ~/.secrets/<name> on home-only.
  host = [
    "personal/sunshine-credentials"
    "personal/tailscale-auth-key"
  ];
};
```

Rules:

- `scopes` must be a unique subset of `[ "personal" "work" ]`.
- `password`, `apps`, and `host` entries must be `<scope>/<name>`.
- The scope prefix must also appear in `scopes`.
- `password` is optional. If absent, the fallback hash in the host declaration is used.
- `apps` and `host` default to empty lists.

### 2.3 Host matrix

| Host | scopes | password | apps | host secrets |
|---|---|---|---|---|
| `hosts/personal/nixos` | personal, work | `personal/main` | personal/opencode-go-key, work/cursor-api-key | personal/sunshine-credentials, personal/tailscale-auth-key |
| `hosts/personal/work` | personal, work | `personal/work` | personal/opencode-go-key, work/cursor-api-key | personal/tailscale-auth-key |
| `hosts/personal/mint` | personal, work | none | personal/opencode-go-key, work/cursor-api-key | personal/tailscale-auth-key |
| `hosts/work/home` | work | none | work/cursor-api-key | none |
| `hosts/vm` | personal, work | none | explicit personal/work entries | none |
| `hosts/personal/generic` | personal | none | personal/opencode-go-key | none |
| `hosts/ci` | none | none | none | none |

`hosts/personal/work` and `hosts/work/home` remain separate machines with separate declarations.

Password names are provisional. Confirm `personal/main` and `personal/work`, or rename before migration.

### 2.4 Provisioning map

```text
host declaration
  |
  +-- scopes -------------------------> SSH, VPN, projects, DB, app-secret lookup
  |
  +-- password -----------------------> boot service -> decrypt -> sha-512 -> usermod user/root
  |
  +-- apps ---------------------------> home activation -> ~/.secrets/<slug>
  |
  +-- host ---------------------------> systemd host-secret service -> /run/angst/host-secrets
                                       or home activation -> ~/.secrets
```

---

## 3. Workstream A — explicit host secret model

### A1. Nix evaluation

Files:

- `lib/resolve.nix`
- `lib/build/mkNixos.nix`
- `lib/build/mkHome.nix`
- `modules/secrets.nix`

Changes:

- Parse `decl.secrets` as an attrset with `scopes`, `password`, `apps`, `host`.
- Remove domain-based `scopes` inference at `lib/resolve.nix:139`.
- Expose:
  - `host.scopes`
  - `host.passwordSecret`
  - `host.appSecrets`
  - `host.hostSecrets`
- Keep `host.password` as the fallback login hash only.
- Remove `secrets/master/<hostname>.age` special handling after migration.
- Update both `mkHome` specialArg blocks and the `mkNixos` home-manager specialArg block.

### A2. Password pool

Storage:

```text
secrets/passwords/<scope>/<name>.age
```

Boot behavior:

- `angst-bootstrap-secrets` runs before `getty@.service`, `serial-getty@.service`, and `display-manager.service`.
- It decrypts the selected password with the scope age key.
- It applies the same sha-512 hash to the host user and `root`.
- If the password file is absent or cannot decrypt, it skips and keeps the fallback hash.
- Decrypted plaintext exists only in a temporary directory with mode `0700` and is removed.

CLI changes:

- Replace `angst bootstrap-master-password --host <host>` with:
  ```bash
  angst bootstrap-password --name <name> --scope personal|work
  ```
- Write `secrets/passwords/<scope>/<name>.age`.
- Remove the `strings.Contains(configDir, "/work/")` scope inference.
- `set-password-hash` accepts `--scope` and resolves the correct age key.
- Keep a deprecated `bootstrap-master-password` alias for one release if desired.

Migration note:

- Do not rename `secrets/master/*.age` blindly. The current files may not decrypt with the keys available on a given machine.
- Recreate password entries with `angst bootstrap-password` on a machine holding the intended scope key.
- Keep old master files until the new boot path is verified, then delete `secrets/master/`.

### A3. Host infrastructure secrets

Storage:

```text
secrets/hosts/<hostname>/<name>.age
```

NixOS:

- Add `modules/nixos/host-secrets.nix`.
- One systemd oneshot `angst-provision-host-secrets.service` decrypts declared `secrets.host` entries.
- Output directory: `/run/angst/host-secrets/`, mode `0750 root:<user>`.
- Output files: mode `0640 root:<user>`.
- Decrypt each entry with the age key selected by its scope prefix.
- Service runs before `tailscaled-autoconnect.service`.
- Consumers read the runtime path. Sunshine retries on failure because its user unit already has `Restart=on-failure` and `RestartSec=5`.

Home-only hosts:

- Add a home module that decrypts declared host secrets into `~/.secrets/<name>` with mode `0600`.
- Mint's bootstrap reads `~/.secrets/tailscale-auth-key` instead of a hostname-specific app secret.
- Alternatively, `remote-mint-bootstrap` decrypts directly from the repo and never persists the key.

Consumers:

- Tailscale: `authKeyFile = "/run/angst/host-secrets/tailscale-auth-key"`.
- Sunshine: `ExecStartPre` decrypts or reads `sunshine-credentials`, then runs `sunshine --creds`.
- No consumer hardcodes `tailscale-auth-key-nixos.age`.

### A4. App secrets

Storage remains:

```text
secrets/apps/<scope>/<slug>.age
```

Changes:

- `modules/home/app-secrets.nix` passes scoped entries such as `--slug personal/opencode-go-key`.
- `runtime/angst/internal/system/provision_app_secret.go` parses `<scope>/<slug>`.
- If scoped, only that scope is attempted.
- Destination stays `~/.secrets/<basename>`.
- Remove host infrastructure secrets from `secrets.apps`.

### A5. Scope-aware consumers

Update every decryptor to use the explicit `scopes`:

- `domains/remote/ssh/system.nix`
  - Pass `scopes = hostScopes` to `runtime.ssh-key-provision`.
  - Current behavior tries both scopes.
- `domains/remote/ssh/ssh-provision-home.nix`
  - Already receives `hostScopes`; keep.
- `domains/network/vpn/system.nix` and `home.nix`
  - Replace hardcoded `[ "personal" "work" ]` with `hostScopes`.
- `runtime/angst/internal/projects/cmd_import.go`
  - Add `--scopes`.
  - Import only declared scopes.
- `runtime/angst/internal/projects/cmd_sync.go`
  - Add `--scopes`.
  - Sync only declared scopes.
- `runtime/angst/internal/db/cmd_import.go`
  - Add `--scopes`.
  - Import only declared scopes.
- `runtime/angst/internal/db/cmd_sync.go`
  - Validate each scoped DB slug belongs to a declared scope.
- `runtime/projects-sync.nix`, `runtime/db-*.nix`
  - Pass `hostScopes`.

### A6. Recipes and commands

- `just remote-tailscale-key <hostname> <scope>`
  - Prompt for `tskey-auth-...`.
  - Encrypt to `secrets/hosts/<hostname>/tailscale-auth-key.age`.
  - `chmod 600`, `git add`.
- `just remote-sunshine-secret <hostname> <scope>`
  - Generate a random password.
  - Encrypt to `secrets/hosts/<hostname>/sunshine-credentials.age`.
  - Install plaintext only where the caller needs it.
- `just remote-mint-bootstrap`
  - Decrypt `secrets/hosts/mint/tailscale-auth-key.age` with the personal age key.
  - Run `tailscale up --auth-key -`.
  - Do not copy the key into `~/.secrets`.
- `just bootstrap-secrets` and installer messages use the new password command.

### A7. Checks and tests

Add/extend checks:

- `checks/host-identity.nix`
  - Hostnames are unique across all host declarations.
  - No two directories resolve to the same hostname.
- `checks/secret-declarations.nix`
  - Every host's `scopes` is valid and unique.
  - Every `password`, `apps`, and `host` entry has a valid scope prefix.
  - Every scope prefix is present in `scopes`.
  - Every `secrets/apps/<scope>/<slug>.age` exists and is age-encrypted.
  - Every `secrets/hosts/<hostname>/<name>.age` exists and is age-encrypted.
  - No host infrastructure secret remains under `secrets/apps/`.
- `checks/secrets.nix`
  - Add `secrets/passwords/*` and `secrets/hosts/*` envelope checks.
- `checks/persist-ownership.nix`
  - Update special args for the new secret fields.
- Go tests:
  - scoped app slug parsing;
  - password path selection;
  - `--scopes` filtering for projects and DB;
  - removed directory-based scope inference.

### A8. Migration order

1. Implement the new schema and provisioners with the old master path still supported.
2. Create new password files with `angst bootstrap-password` on a machine with the intended scope key.
3. Add new host secret files:
   - `secrets/hosts/nixos/sunshine-credentials.age`
   - `secrets/hosts/nixos/tailscale-auth-key.age`
   - `secrets/hosts/mint/tailscale-auth-key.age`
   - `secrets/hosts/work/tailscale-auth-key.age`
4. Update all host declarations.
5. Build every host without switching:
   ```bash
   just verify
   just build nixos
   just build work
   just hm mint
   ```
6. Switch and reboot `nixos`; verify password, Tailscale, Sunshine.
7. Switch `work`; verify Tailscale and Moonlight.
8. Update Mint; verify Tailscale and Moonlight.
9. Delete `secrets/master/`, old app-host secrets, and compatibility code.
10. Update docs:
    - `README.md`
    - `openwiki/secrets.md`
    - `openwiki/operations.md`
    - `migration.md`
    - installer text in `runtime/apps/install-nixos.nix`

---

## 4. Workstream B — remote i3 streaming

### B1. Split host and client roles

Files:

- `domains/remote/stream/default.nix`
- `domains/remote/stream/system.nix`
- `domains/remote/stream/home.nix`
- `profiles/remote.nix`

Add:

```nix
options.domains.remote.stream.role = lib.mkOption {
  type = lib.types.enum [ "client" "host" "both" ];
  default = "client";
};
```

Behavior:

- Client:
  - Install Moonlight.
  - Enable Tailscale.
- Host:
  - Enable Sunshine.
  - Enable host-side hardware and input groups.
  - Enable i3 autologin.
- Both:
  - All of the above.

Remove the old `hostType != "nixos"` test from `home.nix`. NixOS clients must get Moonlight too.

### B2. i3 autologin

Host role only:

```nix
services.displayManager = {
  defaultSession = "i3";
  autoLogin = {
    enable = true;
    user = userConfig.username;
  };
};
```

Assertions:

- Host role requires `domains.display.x11.enable`.
- Host role requires `domains.wm.i3.enable`.
- Host role requires a display manager, currently `domains.display.ly.enable`.
- `i3` is present in `config.services.displayManager.sessionData.sessionNames`.

Session caveat:

- Current session names are `i3`, `i3+i3`, and `none+i3`.
- `i3` is the custom `domains/display/x11` session that applies monitors, theme, and starts i3.
- Verify the built `i3.desktop` points to the custom xsession script after building.
- Do not select `i3+i3`; it starts i3 through both the desktop and window-manager paths.

### B3. Tailscale

Common to host and client roles:

- `services.tailscale.enable = true`.
- `openFirewall = true`.
- `networking.firewall.trustedInterfaces = [ "tailscale0" ]`.
- Auth key from declared host secret:

```nix
services.tailscale.authKeyFile =
  "/run/angst/host-secrets/tailscale-auth-key";
```

- Require `personal/tailscale-auth-key` in `secrets.host` unless manual enrollment is explicitly allowed.
- `angst-provision-host-secrets.service` runs before `tailscaled-autoconnect.service`.

Work client:

- Generate a Tailscale auth key.
- Run `just remote-tailscale-key work personal`.
- Commit `secrets/hosts/work/tailscale-auth-key.age`.
- Add `"personal/tailscale-auth-key"` to `hosts/personal/work` `secrets.host`.

If manual enrollment is chosen, skip the key declaration and run `sudo tailscale up` once on work.

### B4. Sunshine

Host role only:

- `services.sunshine.enable = true`.
- `autoStart = true`.
- `openFirewall = false`.
- `capSysAdmin = false`; X11 capture does not need KMS privileges.
- User service remains bound to `graphical-session.target`.
- i3 already starts `graphical-session.target` from its config.
- Credentials:
  - Read `sunshine-credentials` from the provisioned host secret.
  - `ExecStartPre` exits non-zero if the file is not ready; `Restart=on-failure` retries.
  - Or decrypt directly with the user age key in `ExecStartPre` and avoid cross-manager ordering.

Resolution:

- Host desktop stays 1920x1080.
- Moonlight scales to the client.
- No virtual-display prep commands in this phase.

### B5. Host changes

- `hosts/personal/nixos`
  - Keep `remote` profile.
  - Set `domains.remote.stream.role = "host"`.
- `hosts/personal/work`
  - Add `"remote"` profile.
  - Set `domains.remote.stream.role = "client"`.
- `hosts/personal/mint`
  - Keep `remote` profile.
  - Default role is `client`.
- `hosts/work/home`
  - Leave unchanged. It is a separate work machine.
- `hosts/vm`
  - Leave remote out unless a client is explicitly wanted.

---

## 5. Verification

### Build

```bash
just verify
just build nixos
just build work
just hm mint
cd runtime/angst && gofmt -l . && go vet ./... && go test ./...
```

### Host boot

After switching and rebooting `nixos`:

```bash
loginctl list-sessions
pgrep -a i3
systemctl status display-manager
systemctl --user status sunshine
systemctl status angst-bootstrap-secrets
systemctl status angst-provision-host-secrets
systemctl status tailscaled
tailscale status
ss -lntup | grep -E '4798|4799|4801'
ls -l /run/angst/host-secrets
```

Expected:

- Ly auto-logs in `joao`.
- i3 is the custom session.
- Sunshine starts without a manual login.
- Tailscale enrolls from the declared auth key.
- Host secret files are present and readable by `joao`.
- No failed units.

### Secrets

```bash
ls -l ~/.secrets
systemctl status angst-bootstrap-secrets --no-pager
journalctl -u angst-bootstrap-secrets -b --no-pager
```

Expected:

- App secrets at `~/.secrets/<slug>`.
- Login password is the selected pool entry.
- Fallback hash is not used.

### Client

On `work`:

```bash
systemctl status tailscaled
tailscale status
tailscale ping nixos
command -v moonlight
```

Then:

1. Open Moonlight.
2. Add the NixOS Tailscale IP or MagicDNS name.
3. Pair at `http://<nixos-tailscale-name>:47989/pin`.
4. Connect and verify the full i3 desktop.

### Remote reconnect

1. Reboot `nixos` without logging in locally.
2. Wait for Tailscale and Sunshine.
3. Connect from `work` or Mint.
4. Confirm monitors, theme, bar, windows, audio, keyboard, mouse, and gamepad.

---

## 6. Risks and open questions

- Auto-login leaves the physical console logged in. Accepted by the user.
- Cross-manager ordering between system host-secret provisioning and the Sunshine user unit is not guaranteed. Mitigation: retry in Sunshine or decrypt credentials in `ExecStartPre`.
- `defaultSession = "i3"` may resolve to the wrong generated session if module wiring changes. Verify `i3.desktop` and `none+i3.desktop`.
- Tailscale auth keys expire. Re-enrollment needs a new key and a new encrypted file.
- Secret declarations control automation, not cryptographic isolation. A host that has an age key on disk can still decrypt anything encrypted to that key.
- Old `secrets/master/*.age` files may not decrypt with the keys on the current workstation. Recreate passwords; do not rename blindly.
- Password names are provisional. Confirm `personal/main` and `personal/work`.
- Work Tailscale enrollment is assumed declarative. If manual enrollment is preferred, omit the host secret and run `tailscale up` once.
