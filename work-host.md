# Work Host (`hosts/work/home`)

A Debian server accessed over SSH, managed by **home-manager only** (no NixOS). It
lives at `hosts/work/home/default.nix` and produces `homeConfigurations.home`.

This document describes its design: the host decl, the generalized per-host
secret mechanism, and how the company Cursor subscription key is provisioned.

## Why `type = "home"`

This flake builds both NixOS systems (`type = "nixos"`) and home-manager
configs (`type = "home"`). A stock Debian box cannot be a NixOS system, so it is
declared as a `home` host — exactly like `personal/mint`. `lib/discover.nix`
finds it recursively under `hosts/work/home/`, and `lib/flake/context.nix`
keys the resulting home config by `hostname` (`home`).

## Host declaration

`hosts/work/home/default.nix` (modeled on `hosts/personal/mint/default.nix`,
minus the `desktop` profile since this is headless):

```nix
{
  type = "home";                       # home-manager only, no NixOS
  system = "x86_64-linux";             # use aarch64-linux on ARM
  hostname = "home";
  username = "joao";                   # remote login user -> /home/<username>
  theme = "miasma";
  profiles = [
    "base"                             # nushell, starship, nvim, ssh, age, sops, git, ...
    "development"                      # opencode, cursor-cli, sqlit, rainfrog, ...
  ];
  toolchains = "*";
  env = {
    EDITOR = "nvim";
  };
  shell = "";
  sshAgent = {
    enable = true;
    keys = [ "~/.ssh/id_ed25519" "~/.ssh/work_ed25519" ];
  };
  ssh = {
    hosts = [
      { host = "github.com"; hostName = "github.com"; user = "git"; identityFile = "~/.ssh/id_ed25519"; }
      { host = "gitlab.com"; hostName = "gitlab.com"; user = "git"; identityFile = "~/.ssh/work_ed25519"; }
      { host = "work_server"; hostName = "200.152.183.154"; user = "joao"; identityFile = "~/.ssh/work_ed25519"; }
    ];
  };
  secrets.cursorApiKey = {
    target = ".secrets/cursor-api-key";
    mode = "0600";
  };
  # projects = [ "..." ];  # optional opaque ids for the encrypted project store
}
```

No `flake.nix` edits are required — hosts are auto-discovered.

## Secrets: two distinct layers

### `secrets/` (repo root) — shared, scope-based credentials

Holds shared encrypted material (`secrets/ssh/{personal,work}.ed25519.age`,
`secrets/ftp/ftp-server.conf.age`). Encrypted to **scope** age keys (personal
`age17yz…`, work `age1z2r…`), not to individual host keys, so the same file is
decryptable on any host holding that scope's key. Distributed to many hosts by
activation scripts (`angst provision-ssh-key`, the FTP decrypt step).

Governing principle (`secret.md`): **all hosts can use the work key; the
personal key is provisioned only on personal hosts.** So this work server
automatically receives the `work` SSH key from `secrets/ssh/work.ed25519.age`,
but *not* the personal one.

### `secrets.yaml` (per host) — app-level secrets

One sops+age-encrypted YAML per host, decrypted **at activation on that one
host** by sops-nix into `~/.secrets/`. Encrypted to the **host's own age key**
(`~/.config/sops/age/keys.txt`).

Historically `modules/secrets.nix` hardcoded exactly one entry,
`opencodeGoKey` → `~/.secrets/opencode-go-key`, consumed by
`domains/agents/opencode/config/opencode.jsonc` via
`{file:~/.secrets/opencode-go-key}`.

## Generalized per-host secrets

To support arbitrary per-host secrets (e.g. the Cursor key) without
special-casing each app, the secret definitions are sourced from the host decl:

- `lib/resolve.nix`: `secrets = decl.secrets or { };` added to the `host` object.
- `modules/secrets.nix`: `hostSecretDefs = host.secrets or { };`, then
  `sops.secrets = hostSecretDefs // masterPasswordDefs` (`masterPassword` is
  still gated to `host.type == "nixos"`). `secrets-activation.nix` already
  iterates `secretDefs` generically by `target`/`mode`, so it needs no change.
- Existing hosts that relied on the old hardcoded default keep working by
  declaring it explicitly, e.g. `hosts/personal/mint/default.nix` and
  `hosts/vm/default.nix` both gain
  `secrets.opencodeGoKey = { target = ".secrets/opencode-go-key"; mode = "0600"; };`.

## Cursor company subscription key

Cursor on the server reads the API key from the `CURSOR_API_KEY` environment
variable. The key is stored per-host and exported at shell startup by reading
the decrypted file — **never baked into the Nix store as plaintext**.

1. **Declaration** — `hosts/work/home/default.nix` declares
   `secrets.cursorApiKey = { target = ".secrets/cursor-api-key"; mode = "0600"; };`.
2. **Encryption** — `.sops.yaml` gains a rule
   `hosts/work/.*/secrets.yaml$` encrypted to the **work** age public key
   (`age1z2rn3lr0f9s0qnpgk8d7ta2fd79vrl09yxgw8enrcdzqcaaaau0qu7f76p`), matching
   the `secrets/ftp` rule and keeping the personal key off this host.
   Then create the file directly with sops (note: `angst bootstrap-secrets`
   only handles `masterPassword` and is NixOS-oriented, so it is not used here):

   ```bash
   sops hosts/work/home/secrets.yaml   # add: cursorApiKey: "<key>"
   ```

   The server must hold the work private key at `~/.config/sops/age/keys.txt`
   (the work scope key is already provisioned to all hosts via
   `angst provision-ssh-key`).
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
nix build .#homeConfigurations.home   # evaluates + builds, wires sops secrets
nix flake check                       # optional full suite
```

## Deploy to the Debian server (operational step)

On the server (with standalone `nix` + `home-manager`):

1. Ensure `~/.config/sops/age/keys.txt` holds the **work** private age key.
2. Build the activation package on a trusted machine, copy `result`, and run
   `./result/activate` — or point standalone home-manager at
   `homeConfigurations.home` in this flake.

## Open questions / defaults

- `username = "joao"` and `system = "x86_64-linux"` are assumptions; change if
  the server login or architecture differs.
- `opencodeGoKey` is **not** declared on this host (Cursor-only). Add it to
  `secrets` + `secrets.yaml` if opencode should also run here.
