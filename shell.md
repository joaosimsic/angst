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
  # safe — entered via `nix develop .#safe` or `shell safe`.
  # Provides neovim with parsers, LSPs, runtimes, and formatters.
  safe = pkgs.mkShell {
    packages = [ pkgs.neovim pkgs.git ] ++ allToolchainPackages;

    shellHook = ''
      mkdir -p ~/.local/share/tree-sitter
      rm -rf ~/.local/share/tree-sitter/{parser,queries} 2>/dev/null
      ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
      ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    '';
  };

  # dev — entered via `nix develop .#dev` or `shell dev`.
  # Full development environment: safe packages + angst CLI, VM CLI, Rust, QEMU.
  dev = pkgs.mkShell {
    packages = [
      pkgs.neovim pkgs.git angstCli
    ] ++ allToolchainPackages
    ++ (with pkgs; [ openssh qemu cargo rustc rust-analyzer ])
    ++ [ vmOutputs.packages.${system}.default vmOutputs.packages.${system}.vm-run ];
    shellHook = /* same as safe */ '';
  };
};
```

## Usage

```bash
# Via nix develop (from within the repo)
nix develop .#safe   # safe editing environment
nix develop .#dev    # full development environment

# Via the shell CLI (standalone — no nix at runtime)
nix run .#shell -- safe
nix run .#shell -- dev

# Or install globally
nix profile install .#shell
shell safe
shell dev

# Inside either shell:
nvim somefile.php    # parsers, LSPs, tools all work
exit                 # back to host shell
```

## How it works

1. The `shell` CLI binary is built by Nix and wrapped with the store
   paths of all packages baked into `SHELL_SAFE_PATH`, `SHELL_DEV_PATH`,
   `SHELL_TS_PARSERS`, and `SHELL_TS_QUERIES` env vars.
2. At runtime, the binary prepends the appropriate PATH, symlinks the
   tree-sitter parsers and queries into `~/.local/share/tree-sitter/`,
   and `exec`s the user's shell — no `nix` invocation needed.
3. When neovim starts inside the shell, its process loads Nix's glibc.
   Any subsequent `dlopen` of a parser `.so` finds the already-loaded
   Nix glibc, so all symbol versions match.
4. All toolchain packages (LSPs, formatters, linters, runtimes) are
   on `PATH` and also resolve against Nix's glibc.

The same environment can also be entered directly via `nix develop .#safe`
or `nix develop .#dev`, which use the traditional `shellHook` approach.

## Benefits

- **Portable** — works on any Linux host with Nix, regardless of glibc
- **Single source of truth** — one place for the dev environment
- **CI-consistent** — same packages, same versions, same shell hook
- **No monkey-patching** — no patchelf, no LD_PRELOAD, no wrapper scripts
- **Reversible** — `exit` drops back to the unmodified host shell

## SSH host setup (Debian/Ubuntu VM)

On the remote VM, just enter the safe shell:

```bash
cd ~/proj/angst
nix develop .#safe
nvim
```

No system-level changes needed. The Nix daemon handles the rest.
