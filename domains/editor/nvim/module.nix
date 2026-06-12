{ config, lib, pkgs, flakeSelf, renderTemplate, templateTokens, themesLib, ... }:

let
  cfg = config.domains.editor.nvim;

  angstSource = lib.cleanSourceWith {
    src = flakeSelf;
    filter =
      path: type:
      let
        base = builtins.baseNameOf path;
      in
      base != ".git" && base != "result" && !(lib.hasSuffix ".qcow2" base);
  };

  angstPath = config.home.homeDirectory + "/.config/angst";
  nvimConfigPath = angstPath + "/domains/editor/nvim/config";

  tokens = templateTokens {
    inherit lib themesLib;
    theme = config.theme;
    fontFamily = config.font.family;
  };

  themeLua = renderTemplate {
    inherit lib;
    templatePath = ./config/lua/config/theme.lua.template;
    inherit tokens;
  };

  themeLuaFile = pkgs.writeText "nvim-theme.lua" themeLua;
in
{
  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
    };

    xdg.configFile."nvim/init.lua".enable = lib.mkForce false;

    home.activation.seedAngstRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ANGST_SRC=${angstSource}
      ANGST_DST=${lib.escapeShellArg angstPath}
      if [ ! -f "$ANGST_DST/flake.nix" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
        $DRY_RUN_CMD cp -a "$ANGST_SRC" "$ANGST_DST"
        $DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
      fi
    '';

    home.activation.nvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" "seedAngstRepo" ] ''
      set -eu
      CONFIG_PATH=${lib.escapeShellArg nvimConfigPath}
      NVIM_PATH="$HOME/.config/nvim"

      if [ ! -f "$CONFIG_PATH/init.lua" ]; then
        echo "domains.editor.nvim: config not found at $CONFIG_PATH"
        exit 1
      fi

      $DRY_RUN_CMD mkdir -p "$HOME/.config"
      $DRY_RUN_CMD rm -rf "$NVIM_PATH"
      $DRY_RUN_CMD mkdir -p "$NVIM_PATH"
      $DRY_RUN_CMD cp -a "$CONFIG_PATH/." "$NVIM_PATH/"
      $DRY_RUN_CMD mkdir -p "$NVIM_PATH/lua/config"
      $DRY_RUN_CMD cp ${themeLuaFile} "$NVIM_PATH/lua/config/theme.lua"
    '';
  };
}
