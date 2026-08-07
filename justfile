password host="nixos":
    #!/usr/bin/env bash
    read -s -p "Enter password: " pass; echo; \
    read -s -p "Confirm password: " pass2; echo; \
    if [ "$pass" != "$pass2" ]; then echo "Passwords don't match"; exit 1; fi; \
    hash=$(echo "$pass" | openssl passwd -6 -stdin); \
    secrets_file="hosts/{{host}}/secrets.yaml"; \
    if [ -f "$secrets_file" ]; then \
        sops "$secrets_file" | grep -q "^password:" && \
        echo "password: \"$hash\"" | sops --input-type yaml --output-type yaml "$secrets_file" || \
        { echo "Error: failed to update password in $secrets_file"; exit 1; }; \
    else \
        echo "password: \"$hash\"" | sops "$secrets_file" 2>/dev/null || \
        { echo "Error: $secrets_file not found. Create it first with sops."; exit 1; }; \
    fi; \
    echo "Password updated in $secrets_file"

disko host="nixos":
    sudo nix run github:nix-community/disko -- --mode disko hosts/{{host}}/disk.nix

hardware host="nixos":
    nixos-generate-config --show-hardware-config > hosts/{{host}}/hardware.nix

bootstrap host="nixos": disko hardware
    @echo "Now generate SSH host key, encrypt secrets, then 'just switch {{host}}'"

build host="nixos":
    nix build .#nixosConfigurations.{{host}}

switch host="nixos":
    sudo nixos-rebuild switch --flake .#{{host}}

hm host="nixos" user="joao":
    nix build .#homeConfigurations."{{user}}@{{host}}".activationPackage

hm-switch host="nixos" user="joao":
    nix build .#homeConfigurations."{{user}}@{{host}}".activationPackage && ./result/activate

analyze:
    python3 -m scripts.analyze_flake --output analysis.md

check:
    nix flake check

dev:
    nix develop

vm host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix shell ./tools/vm#wrapped -c vm start

vm-ssh host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix shell ./tools/vm#wrapped -c vm ssh --auto-start
