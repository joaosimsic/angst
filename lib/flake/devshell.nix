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

  hostHasVm = host != null && builtins.elem "vm" (host.profiles or [ ]);
  vmHostHasVm = vmHost != null && builtins.elem "vm" (vmHost.profiles or [ ]);

  rustAnalyzerMux = pkgs.writeShellScriptBin "rust-analyzer-mux" ''
    exec ${pkgs.lspmux}/bin/lspmux client --server-path ${pkgs.rust-analyzer}/bin/rust-analyzer "$@"
  '';

  fullDevPackages =
    with pkgs;
    [
      neovim
      git
      runtime.angst-cli
      openssh
      age
      gitleaks
      cargo
      rustc
      rust-analyzer
      lspmux
      rustAnalyzerMux
      go
      gofumpt
      deadnix
      statix
    ]
    ++ lib.optionals hostHasVm [
      qemu
      runtime.vmTool
    ]
    ++ allToolchainPkgs;

  fullVmPackages =
    with pkgs;
    [
      neovim
      git
      runtime.angst-cli
      openssh
      age
      gitleaks
      cargo
      rustc
      rust-analyzer
      lspmux
      rustAnalyzerMux
      go
      gofumpt
      deadnix
      statix
    ]
    ++ lib.optionals vmHostHasVm [
      qemu
      runtime.vmTool
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
          lspmux
          rustAnalyzerMux
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
