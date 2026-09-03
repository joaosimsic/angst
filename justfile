bootstrap-secrets host="nixos":
    angst bootstrap-secrets --host {{host}}

disko host="nixos":
    sudo nix run github:nix-community/disko -- --mode disko hosts/{{host}}/disk.nix

hardware host="nixos":
    nixos-generate-config --show-hardware-config > hosts/{{host}}/hardware.nix

bootstrap-disk host="nixos": disko hardware
    @echo "Disk and hardware bootstrapped for {{host}}."

build host="nixos":
    NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.{{host}} --impure

switch host="nixos":
    sudo nixos-rebuild switch --flake .#{{host}}

hm host="nixos" user="joao":
    NIXPKGS_ALLOW_UNFREE=1 nix build .#homeConfigurations."{{user}}@{{host}}".activationPackage --impure

hm-switch host="":
    @if [ -n "{{host}}" ]; then NIXPKGS_ALLOW_UNFREE=1 nix run .#hm-switch -- switch --flake .#{{host}} --impure; else NIXPKGS_ALLOW_UNFREE=1 nix run .#hm-switch -- switch --flake . --impure; fi

analyze:
    nix run .#analyze -- --output analysis.md

check:
    NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure

verify:
    NIXPKGS_ALLOW_UNFREE=1 nix flake check --no-build --impure

go-fmt:
    for d in angst vm shell analyze; do echo "=== $$d ==="; (cd runtime/$$d && gofmt -l . && go vet ./...); done

go-test:
    for d in angst vm shell analyze; do echo "=== $$d ==="; (cd runtime/$$d && go test ./...); done

vault-test:
    cd runtime/angst && go test ./internal/vault/... -v

dev:
    nix develop

install-hooks:
    git config core.hooksPath githooks

test-secrets:
    nix build '.#checks.x86_64-linux.secret-scan' --no-link --print-build-logs
    nix build '.#checks.x86_64-linux.secret-scan-hooks' --no-link --print-build-logs

vault-encrypt path scope="personal" dir="":
    @angst vault encrypt {{path}} --scope {{scope}} {{ if dir != "" { "--dir" } else { "" } }}

vault-decrypt path scope="personal" dir="":
    @angst vault decrypt {{path}} --scope {{scope}} {{ if dir != "" { "--dir" } else { "" } }}

vault-status path=".":
    angst vault status {{path}}

vm host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix run .#vm -- start

vm-ssh host="nixos":
    @NIX_DEFAULT_TARGET_HOST={{host}} nix run .#vm -- ssh --auto-start

# --- TeX ---
tex file="monografia/main.tex":
    @echo "Compiling {{file}} with latexmk (nix develop .#safe)..."
    nix develop .#safe --command bash -c 'set -e; f="{{file}}"; dir=$(dirname "$f"); base=$(basename "$f"); cd "$dir" && latexmk -pdf -interaction=nonstopmode -halt-on-error "$base" && echo "✓ PDF generated: $dir/${base%.tex}.pdf" || (echo "✗ TeX compilation failed"; exit 1)'

tex-clean file="monografia/main.tex":
    nix develop .#safe --command bash -c 'f="{{file}}"; dir=$(dirname "$f"); base=$(basename "$f"); cd "$dir" && latexmk -C "$base" && echo "Cleaned latexmk artifacts for $base"'

tex-check:
    @echo "Running Nix TeX check (minimal document)..."
    nix build .#checks.x86_64-linux.check-tex --print-build-logs

tex-fmt file="":
    @if [ -z "{{file}}" ]; then echo "Usage: just tex-fmt <file.tex>"; exit 1; fi
    nix develop .#safe --command latexindent -w "{{file}}" && echo "Formatted {{file}}"

tex-lint file="":
    @if [ -z "{{file}}" ]; then echo "Usage: just tex-lint <file.tex>"; exit 1; fi
    nix develop .#safe --command chktex "{{file}}"
