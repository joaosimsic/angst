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
        $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.config/nvim"
        if [ ! -f "${config.home.homeDirectory}/.config/nvim/lazy-lock.json" ]; then
          $DRY_RUN_CMD cp ${./config/lazy-lock.json} "${config.home.homeDirectory}/.config/nvim/lazy-lock.json"
          $DRY_RUN_CMD chmod 600 "${config.home.homeDirectory}/.config/nvim/lazy-lock.json"
        fi
      '';
    };
  };
}
