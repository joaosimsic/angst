{
  pkgs,
  host,
  runtime,
}:

let
  allToolchainPkgs = if host != null then host.scan.allToolchainPackages else [ ];
  treesitter = if host != null then host.scan.treesitter else null;

  treesitterShellHook = ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${
      if treesitter != null then treesitter.treesitterParsers else "/dev/null"
    } ~/.local/share/tree-sitter/parser
    ln -sf ${
      if treesitter != null then treesitter.treesitterQueries else "/dev/null"
    } ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  shellDevHook = runtime.devshellHook {
    defaultVmHost = "vm";
  };

  fullDevPackages =
    with pkgs;
    [
      neovim
      git
      runtime.angstCli
      openssh
      qemu
      age
      runtime.vmTool
      gitleaks
      cargo
      rustc
      rust-analyzer
      go
      gofumpt
      deadnix
      statix
    ]
    ++ allToolchainPkgs;
in
{
  shells = {
    safe = pkgs.mkShell {
      packages =
        with pkgs;
        [
          neovim
          git
          deadnix
          statix
        ]
        ++ allToolchainPkgs;
      shellHook = treesitterShellHook;
    };

    dev = pkgs.mkShell {
      packages = fullDevPackages;
      shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
    };

    vm = pkgs.mkShell {
      packages = fullDevPackages;
      shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
    };
  };
}
