{ pkgs, cfg, inputs, angstCli, vmOutputs, shellOutputs }:

let
  allToolchainPkgs = cfg.scan.allToolchainPackages;
  treesitter = cfg.scan.treesitter;

  treesitterShellHook = ''
    mkdir -p ~/.local/share/tree-sitter
    rm -rf ~/.local/share/tree-sitter/parser ~/.local/share/tree-sitter/queries 2>/dev/null
    ln -sf ${treesitter.treesitterParsers} ~/.local/share/tree-sitter/parser
    ln -sf ${treesitter.treesitterQueries} ~/.local/share/tree-sitter/queries
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
  '';

  shellDevHook = pkgs.writeText "shell-dev-hook" ''
    export VM_SSH_PORT=2222
    export NIX_DEFAULT_TARGET_HOST=${cfg.hostname}
    export CARGO_BUILD_TARGET_DIR="$PWD/target"
    if [ -z "$SSH_AUTH_SOCK" ]; then
      eval $(ssh-agent -s) > /dev/null
      trap "ssh-agent -k > /dev/null" EXIT
    fi
    for key in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_rsa; do
      [ -f "$key" ] && ssh-add "$key" 2>/dev/null || true
    done
  '';

  fullDevPackages = with pkgs; [
    neovim git angstCli openssh qemu cargo rustc rust-analyzer
    deadnix statix
  ] ++ allToolchainPkgs ++ [
    vmOutputs.packages.${cfg.system}.wrapped
    vmOutputs.packages.${cfg.system}.vm-run
    vmOutputs.packages.${cfg.system}.res
  ];
in {
  shells = {
    safe = pkgs.mkShell {
      packages = with pkgs; [ neovim git deadnix statix ] ++ allToolchainPkgs;
      shellHook = treesitterShellHook;
    };

    dev = pkgs.mkShell {
      packages = fullDevPackages;
      shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
    };

    vm = pkgs.mkShell {
      inputsFrom = [ inputs.vm.devShells.${cfg.system}.default ];
      packages = fullDevPackages;
      shellHook = "${treesitterShellHook}\n. ${shellDevHook}";
    };
  };
}
