# Controlled Dev Shell

## Problem

Neovim's tree-sitter parsers are compiled by Nix against Nix's glibc 2.42.
When the host system has an older glibc (e.g. Debian 12 with 2.36),
loading these parsers inside a host-installed neovim fails:

```
/lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
(required by /nix/store/...-gcc-15.2.0-lib/lib/libstdc++.so.6)
```

The root cause: `uv_dlopen` loads the parser `.so` into neovim's process
space, and the already-loaded system `libc.so.6` wins over the parser's
RPATH. Nix's `libstdc++` then tries to resolve `GLIBC_2.38` against the
older system libc and fails.

This affects **all** Nix-built tree-sitter grammar binaries on any host
with glibc < 2.38 (Debian 12, Ubuntu 22.04, etc.).

## Solution: Controlled dev shell (`nix develop`)

Replace ad-hoc monkey-patching with a single, versioned entry point:
**a `default` dev shell** that provides a complete, self-contained
neovim + parser + LSP environment via Nix.

Inside the shell, neovim itself runs from Nix and links against Nix's
glibc, so any `dlopen`'d parser resolves against the same Nix libc.
This works identically on any host with Nix installed, regardless of
the system's glibc version.

## Proposed layout

```nix
devShells.${system} = {
  # Default — entered via `nix develop`.
  # Provides a working neovim with parsers, LSPs, runtimes, and formatters.
  default = pkgs.mkShell {
    packages = [
      pkgs.neovim
      pkgs.git
      angstCli
    ] ++ allToolchainPackages;

    shellHook = ''
      mkdir -p ~/.local/share/tree-sitter
      rm -rf ~/.local/share/tree-sitter/{parser,queries} 2>/dev/null
      ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
      ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    '';
  };

  # CI — inherits from default, adds CI-specific overrides.
  nvim-test = pkgs.mkShell {
    inputsFrom = [ self.devShells.${system}.default ];
    packages = [ pkgs.git ];
    # CI-specific shellHook additions…
  };
};
```

## Usage

```bash
# Enter the controlled shell
nix develop

# Neovim works with all parsers, LSPs, tools
nvim somefile.php
nvim somefile.py

# Exit returns to the bare host shell
exit
```

## How it works

1. `nix develop` evaluates the default dev shell, which includes
   `pkgs.neovim` — built by Nix against Nix's glibc.
2. The `shellHook` symlinks the Nix-built tree-sitter parsers and
   queries into `~/.local/share/tree-sitter/`, where neovim expects
   them.
3. When neovim starts inside the shell, its process loads Nix's glibc.
   Any subsequent `dlopen` of a parser `.so` finds the already-loaded
   Nix glibc, so all symbol versions match.
4. All toolchain packages (LSPs, formatters, linters, runtimes) are
   on `PATH` and also resolve against Nix's glibc.

## Benefits

- **Portable** — works on any Linux host with Nix, regardless of glibc
- **Single source of truth** — one place for the dev environment
- **CI-consistent** — same packages, same versions, same shell hook
- **No monkey-patching** — no patchelf, no LD_PRELOAD, no wrapper scripts
- **Reversible** — `exit` drops back to the unmodified host shell

## SSH host setup (Debian/Ubuntu VM)

On the remote VM, just enter the shell as usual:

```bash
cd ~/proj/angst
nix develop
nvim
```

No system-level changes needed. The Nix daemon handles the rest.
