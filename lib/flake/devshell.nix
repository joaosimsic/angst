{
  pkgs,
  host,
  inputs,
  runtime,
  vmOutputs,
}:

let
  allToolchainPkgs = host.scan.allToolchainPackages;
  treesitter = host.scan.treesitter;

  treesitterShellHook = ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
    ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  shellDevHook = runtime.devshellHook {
    defaultVmHost = inputs.vm.defaultVmHost;
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
      gitleaks
      cargo
      rustc
      rust-analyzer
      go
      gofumpt
      deadnix
      statix
    ]
    ++ allToolchainPkgs
    ++ [
      vmOutputs.packages.${host.system}.wrapped
    ];
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
      inputsFrom = [ inputs.vm.devShells.${host.system}.default ];
      packages = fullDevPackages;
      shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
    };
  };
}
