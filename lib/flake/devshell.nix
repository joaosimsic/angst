{
  pkgs,
  host,
  vmHost,
  runtime,
}:

let
  allToolchainPkgsFor = h: if h != null then h.scan.allToolchainPackages else [ ];
  treesitterFor = h: if h != null then h.scan.treesitter else null;

  allToolchainPkgs = allToolchainPkgsFor host;
  treesitter = treesitterFor host;

  vmAllToolchainPkgs = allToolchainPkgsFor (if vmHost != null then vmHost else host);
  vmTreesitter = treesitterFor (if vmHost != null then vmHost else host);

  treesitterShellHookFor = t: ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${if t != null then t.treesitterParsers else "/dev/null"} ~/.local/share/tree-sitter/parser
    ln -sf ${if t != null then t.treesitterQueries else "/dev/null"} ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  treesitterShellHook = treesitterShellHookFor treesitter;
  vmTreesitterShellHook = treesitterShellHookFor vmTreesitter;

  shellDevHook = runtime.devshell-hook {
    defaultVmHost = "vm";
  };

  fullDevPackages =
    with pkgs;
    [
      neovim
      git
      runtime.angst-cli
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

  fullVmPackages =
    with pkgs;
    [
      neovim
      git
      runtime.angst-cli
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
    ++ vmAllToolchainPkgs;
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
      packages = fullVmPackages;
      shellHook = "${vmTreesitterShellHook}\n. ${shellDevHook}";
    };
  };
}
