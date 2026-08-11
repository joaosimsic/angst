{
  self,
  context,
}:

let
  inherit (context)
    pkgs
    representative
    defaultSystem
    angstTool
    vmOutputs
    shellTool
    ;

  mkApp = program: {
    type = "app";
    inherit program;
  };
in
{
  apps.${defaultSystem} = {
    vm = mkApp "${vmOutputs.packages.${defaultSystem}.wrapped}/bin/vm";
    shell = mkApp "${shellTool}/bin/shell";
    angst = mkApp "${angstTool}/bin/angst";
    render = mkApp "${pkgs.writeShellScript "angst-render" ''exec ${angstTool}/bin/angst render "$@"''}";
    watch = mkApp "${pkgs.writeShellScript "angst-watch" ''exec ${angstTool}/bin/angst watch "$@"''}";
    check = mkApp "${pkgs.writeShellScript "check" "set -euo pipefail; ${pkgs.nix}/bin/nix flake check --print-build-logs"}";
    lint-themes = mkApp "${pkgs.writeShellScript "lint-themes" "set -euo pipefail; ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw"}";
    lint-desktop = mkApp "${pkgs.writeShellScript "lint-desktop" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-desktop --no-link --print-build-logs; echo "All desktop config checks passed."''}";
    lint-shell = mkApp "${pkgs.writeShellScript "lint-shell" ''set -euo pipefail; ${pkgs.nix}/bin/nix build ${self}#checks.${defaultSystem}.lint-shell --no-link --print-build-logs; echo "All shell config checks passed."''}";
    analyze = mkApp "${pkgs.writeShellScript "analyze" ''exec python3 -m scripts.analyze_flake "$@"''}";
    analyze-to-file = mkApp "${pkgs.writeShellScript "analyze-to-file" ''cd "$(git rev-parse --show-toplevel)" && exec python3 -m scripts.analyze_flake --output analysis.md "$@"''}";
  }
  // (
    if representative != null then
      {
        ssh =
          let
            target = representative.username;
          in
          mkApp "${pkgs.writeShellScript "angst-ssh-deploy" ''
            set -euo pipefail
            target="''${NIX_DEFAULT_TARGET_HOST:-${target}}"
            echo "==> Deploying home-manager to $target..."
            nix build ${self}#homeConfigurations.${target}.activationPackage --print-build-logs
            echo "==> Activating..."; ./result/activate
            echo "==> Cleaning old Nix store..."; nix-collect-garbage -d; nix store gc; echo "==> Done."
          ''}";
      }
    else
      { }
  );
}
