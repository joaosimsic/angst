# Recipe arguments are POSITIONAL: `just hm-switch nixos`, `just hardware personal/nixos`.
# The `name=value` form does NOT work for recipe parameters in just 1.58 — overrides are
# only accepted for global variables, and a `name=value` placed after the recipe name is
# passed through as a literal string. So `just hm-switch host=nixos` silently expands to
# `--flake .#host=nixos` and fails with a confusing "does not provide attribute" error.
# Run `just --list` to see each recipe's parameter names.

set shell := ["bash", "-c"]

bootstrap-password name="main" scope="personal":
    angst bootstrap-password --name {{ name }} --scope {{ scope }}

install-nixos *args:
    sudo nix run .#install-nixos -- {{ args }}

generic-provision *args:
    sudo nix --extra-experimental-features 'nix-command flakes' run .#generic-provision -- {{ args }}

generic-switch *args:
    nix --extra-experimental-features 'nix-command flakes' run .#generic-switch -- {{ args }}

test-generic-contract:
    NIXPKGS_ALLOW_UNFREE=1 nix build .#checks.x86_64-linux.generic-host-contract .#checks.x86_64-linux.generic-host-guard .#checks.x86_64-linux.generic-provision-safety --impure --no-link

test-generic-provision:
    NIXPKGS_ALLOW_UNFREE=1 nix build .#tests.x86_64-linux.generic-provision-no-btrfs .#tests.x86_64-linux.generic-provision --impure --no-link --print-build-logs

reinstall *args:
    sudo nix run .#install-nixos -- --fresh --yes {{ args }}

provision-dual *args:
    sudo nix run .#install-nixos --extra-experimental-features nix-command --extra-experimental-features flakes -- --dual-boot --yes {{ args }}

provision-full *args:
    sudo nix run .#install-nixos -- --full-disk --yes {{ args }}

hardware path="personal/nixos":
    nixos-generate-config --show-hardware-config > hosts/{{ path }}/hardware.nix

build host="nixos":
    NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel --impure

switch host="nixos":
    sudo nixos-rebuild switch --flake .#{{ host }}

hm host="nixos":
    NIXPKGS_ALLOW_UNFREE=1 nix build .#homeConfigurations.{{ host }}.activationPackage --impure

hm-switch host="":
    @if [ -n "{{ host }}" ]; then NIXPKGS_ALLOW_UNFREE=1 nix run .#hm-switch -- switch --flake .#{{ host }} --impure; else NIXPKGS_ALLOW_UNFREE=1 nix run .#hm-switch -- switch --flake . --impure; fi

install-paper:
    NIXPKGS_ALLOW_UNFREE=1 nix profile install .#paper-desktop --impure

analyze:
    nix run .#analyze -- --output analysis.md

check:
    NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure

verify:
    NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure

go-fmt:
    for d in runtime/angst runtime/vm runtime/shell runtime/analyze domains/wm/i3/workspace-group domains/chat/discord/voice-status; do echo "=== $d ==="; (cd $d && gofmt -l . && CGO_ENABLED=0 go vet ./...); done

go-test:
    for d in runtime/angst runtime/vm runtime/shell runtime/analyze domains/wm/i3/workspace-group domains/chat/discord/voice-status; do echo "=== $d ==="; (cd $d && CGO_ENABLED=0 go test ./...); done

vault-test:
    cd runtime/angst && go test ./internal/vault/... -v

dev:
    nix develop

install-hooks:
    git config core.hooksPath githooks

# Repair .git/objects entries owned by root; no-op when none.
fix-git-objects:
    sudo find .git/objects -user root -exec chown "$(id -u):$(id -g)" {} +

test-secrets:
    nix build '.#checks.x86_64-linux.secret-scan' --no-link --print-build-logs
    nix build '.#checks.x86_64-linux.secret-scan-hooks' --no-link --print-build-logs

vault-encrypt path scope="personal" dir="":
    @angst vault encrypt {{ path }} --scope {{ scope }} {{ if dir != "" { "--dir" } else { "" } }}

vault-decrypt path scope="personal" dir="":
    @angst vault decrypt {{ path }} --scope {{ scope }} {{ if dir != "" { "--dir" } else { "" } }}

vault-status path=".":
    angst vault status {{ path }}

vm host="vm":
    @NIX_DEFAULT_TARGET_HOST={{ host }} nix run .#vm -- start

vm-ssh host="vm":
    @NIX_DEFAULT_TARGET_HOST={{ host }} nix run .#vm -- ssh --auto-start

# Encrypt a Tailscale auth key for a host into secrets/tailscale/<hostname>.age.
remote-tailscale-key name scope="personal":
    @case "{{ name }}" in ""|*/*|.*) echo "usage: just remote-tailscale-key <hostname> [personal|work]"; exit 2 ;; esac; \
      case "{{ scope }}" in personal|work) ;; *) echo "invalid scope: {{ scope }}"; exit 2 ;; esac; \
      read -rsp "Tailscale auth key for {{ name }}: " key; echo; \
      case "$key" in tskey-auth-*) ;; *) echo "invalid Tailscale auth key"; exit 1 ;; esac; \
      keyfile="$HOME/.config/age/keys.txt"; [ "{{ scope }}" = work ] && keyfile="$HOME/.config/age/work-keys.txt"; \
      mkdir -p "secrets/tailscale"; \
      printf '%s' "$key" | age -r "$(age-keygen -y "$keyfile")" -o "secrets/tailscale/{{ name }}.age"; \
      chmod 600 "secrets/tailscale/{{ name }}.age"; \
      git add "secrets/tailscale/{{ name }}.age"

# Generate and encrypt Sunshine web credentials for a host.
remote-sunshine-secret name="nixos" scope="personal":
    @case "{{ name }}" in ""|*/*|.*) echo "usage: just remote-sunshine-secret <hostname> [personal|work]"; exit 2 ;; esac; \
      case "{{ scope }}" in personal|work) ;; *) echo "invalid scope: {{ scope }}"; exit 2 ;; esac; \
      read -rp "Sunshine username [joao]: " user; user=${user:-joao}; \
      pass=$(openssl rand -base64 24 | tr -d '\n'); \
      keyfile="$HOME/.config/age/keys.txt"; [ "{{ scope }}" = work ] && keyfile="$HOME/.config/age/work-keys.txt"; \
      mkdir -p "secrets/sunshine"; \
      printf '%s\n%s\n' "$user" "$pass" | age -r "$(age-keygen -y "$keyfile")" -o "secrets/sunshine/{{ name }}.age"; \
      chmod 600 "secrets/sunshine/{{ name }}.age"; \
      git add "secrets/sunshine/{{ name }}.age"; \
      echo "Sunshine credentials encrypted at secrets/sunshine/{{ name }}.age"

# Run on Mint: activate home config, install Tailscale, enroll with the mint auth key.
remote-mint-bootstrap:
    just hm-switch mint
    @test -f "$HOME/.secrets/tailscale" || { echo "missing ~/.secrets/tailscale; run: just remote-tailscale-key mint && just hm-switch mint"; exit 1; }
    @command -v tailscale >/dev/null 2>&1 || sudo sh -c 'curl -fsSL https://tailscale.com/install.sh | sh'
    @sudo tailscale up --auth-key "file:$HOME/.secrets/tailscale" --timeout=60s
    @if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q 'Status: active'; then sudo ufw allow in on tailscale0; fi
    @sudo tailscale status
    @echo "Open Moonlight, add the NixOS Tailscale IP or MagicDNS name, then enter the Sunshine PIN."

# Recover from a stale/duplicate Tailscale node key.
remote-mint-reauth:
    just hm-switch mint
    @test -f "$HOME/.secrets/tailscale" || { echo "missing ~/.secrets/tailscale; run: just remote-tailscale-key mint && just hm-switch mint"; exit 1; }
    @sudo tailscale up --auth-key "file:$HOME/.secrets/tailscale" --force-reauth --timeout=60s
    @sudo tailscale status

# Last resort: reset the local Tailscale node identity (backs up state).
remote-mint-reset-tailscale:
    just hm-switch mint
    @test -f "$HOME/.secrets/tailscale" || { echo "missing ~/.secrets/tailscale; run: just remote-tailscale-key mint && just hm-switch mint"; exit 1; }
    @sudo systemctl stop tailscaled
    @if [ -f /var/lib/tailscale/tailscaled.state ]; then sudo mv /var/lib/tailscale/tailscaled.state "/var/lib/tailscale/tailscaled.state.bak-$(date +%s)"; fi
    @sudo systemctl start tailscaled
    @sudo tailscale up --auth-key "file:$HOME/.secrets/tailscale" --timeout=60s
    @sudo tailscale status
