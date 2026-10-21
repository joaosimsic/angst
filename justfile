# Recipe arguments are POSITIONAL: `just hm-switch nixos`, `just hardware personal/nixos`.
# The `name=value` form does NOT work for recipe parameters in just 1.58 — overrides are
# only accepted for global variables, and a `name=value` placed after the recipe name is
# passed through as a literal string. So `just hm-switch host=nixos` silently expands to
# `--flake .#host=nixos` and fails with a confusing "does not provide attribute" error.
# Run `just --list` to see each recipe's parameter names.

bootstrap-secrets host="nixos":
    angst bootstrap-secrets --host {{ host }}

install-nixos *args:
    sudo nix run .#install-nixos -- {{ args }}

generic-provision *args:
    sudo nix --extra-experimental-features 'nix-command flakes' run .#generic-provision -- {{ args }}

generic-switch *args:
    nix --extra-experimental-features 'nix-command flakes' run .#generic-switch -- {{ args }}

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
    for d in runtime/angst runtime/vm runtime/shell runtime/analyze domains/wm/i3/workspace-group; do echo "=== $d ==="; (cd $d && gofmt -l . && go vet ./...); done

go-test:
    for d in runtime/angst runtime/vm runtime/shell runtime/analyze domains/wm/i3/workspace-group; do echo "=== $d ==="; (cd $d && go test ./...); done

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
