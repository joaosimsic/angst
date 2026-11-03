#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

for tool in git go statix deadnix nixfmt nix-instantiate yamllint golangci-lint; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'static-analysis: missing %s; run via: nix-shell infra/static-analysis/shell.nix --run ./infra/static-analysis/static-analysis.sh\n' "$tool" >&2
        exit 1
    fi
done

mapfile -d '' -t nix_files < <(git ls-files -z -- '*.nix')
if ((${#nix_files[@]} == 0)); then
    printf 'static-analysis: no tracked Nix files found\n' >&2
    exit 1
fi

statix check .
deadnix --fail .
nixfmt --check "${nix_files[@]}"

mapfile -d '' -t yaml_files < <(git ls-files -z -- '*.yml' '*.yaml')
if ((${#yaml_files[@]} > 0)); then
    yamllint "${yaml_files[@]}"
fi

(
    cd infra/static-analysis/exportcheck
    go run . "$root"
)

mapfile -d '' -t go_files < <(git ls-files -z -- '*.go')
if ((${#go_files[@]} > 0)); then
    unformatted="$(gofmt -l "${go_files[@]}")"
    if [[ -n "$unformatted" ]]; then
        printf 'static-analysis: gofmt required for:\n%s\n' "$unformatted" >&2
        exit 1
    fi
fi

mapfile -d '' -t go_modules < <(git ls-files -z -- '*go.mod')
for mod in "${go_modules[@]}"; do
    dir="${mod%/go.mod}"
    [[ -n "$dir" ]] || dir="."
    (
        cd "$dir"
        CGO_ENABLED=0 go vet ./...
        golangci-lint run ./...
    )
done
