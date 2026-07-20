password:
    #!/usr/bin/env bash
    read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$pass" != "$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$(echo "$pass" | openssl passwd -6 -stdin); \
    grep -q '^  password = ' local/config.nix && sed -i 's|^  password = ".*";$|  password = "'"$hash"'";|' local/config.nix || sed -i '/^  toolchains = /a\  password = "'"$hash"'";' local/config.nix


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
    @nix shell ./tools/vm#wrapped -c vm ssh --auto-start
