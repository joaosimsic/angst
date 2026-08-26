{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.shell.carapace.enable {
    home = {
      packages = [ pkgs.carapace ];
      activation.carapace-init = lib.hm.dag.entryAfter [ "installPackages" ] ''
        $DRY_RUN_CMD mkdir -p "$HOME/.cache/carapace"
        $DRY_RUN_CMD rm -f "$HOME/.cache/carapace/init.nu"
        $DRY_RUN_CMD $VERBOSE_ECHO "Generating carapace nushell completions..."
        $DRY_RUN_CMD ${pkgs.carapace}/bin/carapace _carapace nushell > "$HOME/.cache/carapace/init.nu"
      '';
    };
  };
}
