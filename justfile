bootstrap-secrets host="nixos":
    angst bootstrap-secrets --host {{host}}

disko host="nixos":
    sudo nix run github:nix-community/disko -- --mode disko hosts/{{host}}/disk.nix

hardware host="nixos":
    nixos-generate-config --show-hardware-config > hosts/{{host}}/hardware.nix

bootstrap-disk host="nixos": disko hardware
    @echo "Disk and hardware bootstrapped for {{host}}."

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

install-hooks:
    git config core.hooksPath githooks

vm host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix shell ./tools/vm#wrapped -c vm start

vm-ssh host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix shell ./tools/vm#wrapped -c vm ssh --auto-start
