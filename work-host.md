# Work Host (`hosts/work/home`)

A Debian server accessed over SSH, managed by **home-manager only** (no NixOS).
It lives at `hosts/work/home/default.nix` and produces
`homeConfigurations.home`.

This document describes its design: the host decl, the **unified scope-based
secret store**, and how the company Cursor subscription key is provisioned.

## Why `type = "home"`

This flake builds both NixOS systems (`type = "nixos"`) and home-manager
configs (`type = "home"`). A stock Debian box cannot be a NixOS system, so it is
declared as a `home` host — exactly like `personal/mint`. `lib/discover.nix`
finds it recursively under `hosts/work/home/`, and `lib/flake/context.nix`
keys the resulting home config by `hostname` (`home`).

## Scope model (the central design point)

Secrets are **scope-based**, not per-host. A host never declares a scope; its
allowed scopes are **inferred from the folder it lives in**:

| Host folder            | allowed scopes            |
|------------------------|---------------------------|
| `hosts/work/**`        | `[ "work" ]`              |
| `hosts/personal/**`    | `[ "personal" "work" ]`   |
| `hosts/vm`             | `[ "personal" "work" ]`   |
| everything else (`ci`)| `[ "work" ]`              |

Implemented in `lib/resolve.nix` as `host.scopes` (derived — no per-host field).
The rule that matters here: **a work host is strictly work-only**. It never
receives the personal age key, so personal secrets are undecryptable on it by
construction.

This is enforced in two places:

- **`angst provision-ssh-key`** is scope-aware: it only installs the scopes the
  host is allowed, so a work host gets `work-keys.txt` + `work_ed25519` and
  never `keys.txt` + `id_ed25519`.
- **The app-secret provisioner** only looks under `secrets/apps/<allowedScope>/`,
  so a work host can resolve `secrets/apps/work/*` but not `secrets/apps/personal/*`.

## Host declaration

`hosts/work/home/default.nix` (modeled on `hosts/personal/mint/default.nix`,
minus the `desktop` profile since this is headless). Note what is **absent**:
no `id_ed25519`, no `github.com` (personal) entry, and `secrets` is just a list
of slugs:

```nix
{
  type = "home";                       # home-manager only, no NixOS
  system = "x86_64-linux";             # use aarch64-linux on ARM
  hostname = "home";
  username = "joao";                   # remote login user -> /home/<username>
  theme = "miasma";
  profiles = [
    "base"                             # nushell, starship, nvim, ssh, age, git, ...
    "development"                      # opencode, cursor-cli, sqlit, rainfrog, ...
  ];
  toolchains = "*";
  env = {
    EDITOR = "nvim";
  };
  shell = "";
  sshAgent = {
    enable = true;
    keys = [ "~/.ssh/work_ed25519" ];  # no id_ed25519: work host is work-only
  };
  ssh = {
    hosts = [
      { host = "gitlab.com"; hostName = "gitlab.com"; user = "git"; identityFile = "~/.ssh/work_ed25519"; }
      { host = "work_server"; hostName = "200.152.183.154"; user = "joao"; identityFile = "~/.ssh/work_ed25519"; }
      # github.com (personal key) is intentionally omitted
    ];
  };
  secrets = [ "cursor-api-key" ];      # slug list; scope + target + mode are inferred
  # projects = [ "..." ];  # optional slug ids for the encrypted project store
}
```

No `flake.nix` edits are required — hosts are auto-discovered.

## Secrets: one unified scope store

All encrypted credentials live under `secrets/` at the repo root, encrypted to
**scope** age keys (personal `age17yz…`, work `age1z2r…`), so the same file is
decryptable on any host holding that scope's key:

- `secrets/ssh/{personal,work}.ed25519.age` — shared SSH keys
- `secrets/ftp/ftp-server.conf.age` — FTP creds
- `secrets/apps/<scope>/<slug>.age` — **app-level secrets** (new)

These are raw `age` files (like `secrets/ssh/*.age`), encrypted with the scope's
public key and decrypted at activation with the matching scope age key
(`~/.config/sops/age/work-keys.txt` for `work`,
`~/.config/sops/age/keys.txt` for `personal`). No per-host `secrets.yaml` and no
sops rules are involved for app secrets.

A host requests app secrets by **slug list** only:

```nix
secrets = [ "cursor-api-key" ];
```

For each slug the provisioner:

1. searches `secrets/apps/<scope>/<slug>.age` across the host's allowed scopes;
2. decrypts the first hit with that scope's age key;
3. writes it to `~/.secrets/<slug>` with mode `0600`.

So **target and mode need not be declared** — they default to
`.secrets/<slug>` + `0600`, and the scope is inferred from the folder. A work
host searching only `secrets/apps/work/` can never materialize a personal secret.

> Per-host `secrets.yaml` (sops-nix) is retained **only** for the NixOS
> `masterPassword` bootstrap. App secrets no longer live there.

### Historical note: `opencode-go-key`

Previously `modules/secrets.nix` hardcoded `opencodeGoKey` →
`~/.secrets/opencode-go-key`. It now follows the same unified model:

- file: `secrets/apps/personal/opencode-go-key.age` (encrypted to the personal
  key, since it is a personal-scope secret);
- declared on personal/vm hosts as `secrets = [ "opencode-go-key" ];`;
- consumed unchanged by `domains/agents/opencode/config/opencode.jsonc` via
  `{file:~/.secrets/opencode-go-key}`.

Because `opencode-go-key` is personal-scope, a work host (allowed `[ "work" ]`)
will not receive it — which is the desired isolation.

## Cursor company subscription key

Cursor on the server reads the API key from the `CURSOR_API_KEY` environment
variable. The key is stored in the scope store and exported at shell startup by
reading the decrypted file — **never baked into the Nix store as plaintext**.

1. **Declaration** — `hosts/work/home/default.nix` lists
   `secrets = [ "cursor-api-key" ];`.
2. **Encryption** — create the scope file directly with `age` (no sops needed),
   encrypted to the **work** public key:

   ```bash
   age --encrypt -R secrets/ssh/work.ed25519.pub \
     -o secrets/apps/work/cursor-api-key.age ./cursor-key-plaintext
   ```

   The server must hold the work private key at
   `~/.config/sops/age/work-keys.txt` (provisioned to work hosts by
   `angst provision-ssh-key`). Personal hosts never get this key, so the Cursor
   key is undecryptable there unless they are also allowed the work scope (they
   are, by the rule above — the work key is shared; only the *personal* key is
   restricted).
3. **Wiring** — `domains/agents/cursor-cli/home.nix` (new) exports the variable
   at shell startup, reading the file at runtime:

   ```nix
   config = lib.mkIf config.domains.agents.cursor-cli.enable {
     programs.bash.bashrcExtra = lib.mkAfter ''
       if [ -f "$HOME/.secrets/cursor-api-key" ]; then
         export CURSOR_API_KEY="$(cat "$HOME/.secrets/cursor-api-key")"
       fi
     '';
     programs.nushell.extraConfig = lib.mkAfter ''
       if ("$HOME/.secrets/cursor-api-key" | path exists) {
         $env.CURSOR_API_KEY = (open "$HOME/.secrets/cursor-api-key" | str trim)
       }
     '';
   };
   ```

   The `cursor-cli` package is auto-installed by the domain framework's
   `baseModule` (`package = "cursor-cli"` in `domains/agents/cursor-cli/default.nix`),
   so no `home.packages` entry is needed.

## Build & verify

```bash
nix build .#homeConfigurations.home   # evaluates + builds, wires scope secrets
nix flake check                       # optional full suite
```

## Deploy to the Debian server (operational step)

On the server (with standalone `nix` + `home-manager`):

1. Ensure `~/.config/sops/age/work-keys.txt` holds the **work** private age key
   (no `keys.txt` / personal key — this host is work-only).
2. Build the activation package on a trusted machine, copy `result`, and run
   `./result/activate` — or point standalone home-manager at
   `homeConfigurations.home` in this flake.

## Defaults / open questions

- `username = "joao"` and `system = "x86_64-linux"` are assumptions; change if
  the server login or architecture differs.
- `opencode-go-key` is **not** provisioned to this host (work-only, and it is a
  personal-scope secret). Add `"opencode-go-key"` to `secrets` here only if
  opencode should also run on the work server.
