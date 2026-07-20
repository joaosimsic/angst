password:
    #!/usr/bin/env bash
    read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$pass" != "$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$(echo "$pass" | openssl passwd -6 -stdin); \
    sed -i "s|\$6\$CHANGEME\$REPLACE_WITH_REAL_HASH|$hash|" local/config.nix


disko:
    sudo nix run github:nix-community/disko -- --mode disko local/disk.nix

hardware:
    nixos-generate-config --show-hardware-config > local/hardware.nix

bootstrap: disko hardware
    @echo "Now write local/config.nix, run 'just password', then 'just build'"

build:
    nix build .#nixosConfigurations.current --impure

switch:
    sudo nixos-rebuild switch --flake .#current --impure

hm:
    nix build .#homeConfigurations.current.activationPackage --impure

hm-switch:
    nix build .#homeConfigurations.current.activationPackage --impure && ./result/activate

analyze:
    python3 -m scripts.analyze_flake --output analysis.md

check:
    nix flake check --impure

dev:
    nix develop --impure

vm:
    @nix shell ./tools/vm#wrapped -c vm start

vm-ssh:
    @if ! ss -tlnp 'sport = :2222' | grep -q LISTEN 2>/dev/null; then \
        echo "VM not running. Starting headless..."; \
        nix shell ./tools/vm#wrapped -c vm start --headless; \
    fi; \
    nix shell ./tools/vm#wrapped -c vm ssh
