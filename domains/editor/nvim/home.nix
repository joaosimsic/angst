{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.editor.nvim;
in
{
  config = lib.mkIf cfg.enable {
    home = {
      packages = [ pkgs.neovim ];

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      shellAliases = {
        vi = "nvim";
        vim = "nvim";
      };

      activation.seedNvimLazyLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        lock="${config.home.homeDirectory}/.config/nvim/lazy-lock.json"
        $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.config/nvim"
        if [ -L "$lock" ] && [ ! -e "$lock" ]; then
          $DRY_RUN_CMD rm -f "$lock"
        fi
        if [ ! -e "$lock" ]; then
          $DRY_RUN_CMD cp ${./config/lazy-lock.json} "$lock"
          $DRY_RUN_CMD chmod 600 "$lock"
        fi
      '';
    };
  };
}
