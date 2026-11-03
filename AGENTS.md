# Agent instructions

## Coding style

Read and follow [`CODING_STYLE.md`](./CODING_STYLE.md) for all code changes. It is mandatory for new and modified code. Do not copy nearby violations. If existing code conflicts with the style, follow the style and refactor the touched code.

## Mandatory static analysis

Before reporting any code change complete, run from the repository root:

```bash
nix-shell infra/static-analysis --run ./infra/static-analysis/static-analysis.sh
```

If `statix`, `deadnix`, `nixfmt`, `nix-instantiate`, `golangci-lint`, and Go are already on `PATH`, `./infra/static-analysis/static-analysis.sh` is equivalent.

This validation is mandatory and repo-wide. Do not replace it with a per-file or narrowed command. Do not suppress, disable, or ignore warnings. Fix failures before finishing.

## What it enforces

- `statix check .`
- `deadnix --fail .`
- `nixfmt --check` on every tracked `.nix` file
- export-use check: global exports used outside their module; private module exports used inside their module; test files never justify exports
- `gofmt -l` on every tracked `.go` file
- `CGO_ENABLED=0 go vet ./...` in every Go module
- `golangci-lint run ./...` in every Go module

Format changed files before rerunning: `nixfmt` for Nix, `gofmt -w` for Go.

## Domain tests

`infra/static-analysis/static-analysis.sh` is static-only. Functional gates remain in:

- `.github/workflows/secret-privacy.yml`
- `.github/workflows/log-vocab-parity.yml`

Run the relevant workflow commands when changing those domains.
