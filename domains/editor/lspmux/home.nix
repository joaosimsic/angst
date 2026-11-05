{
  config,
  lib,
  pkgs,
  store ? { },
  ...
}:

let
  cfg = config.domains.editor.lspmux;
  socket = "/run/user/1000/lspmux.sock";
  hasRust = (store.editorLsp or { }) ? rust;
  hasGo = (store.editorLsp or { }) ? gopls;
  rustAnalyzerMux = pkgs.writeShellScriptBin "rust-analyzer-mux" ''
    exec ${pkgs.lspmux}/bin/lspmux client "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    home = {
      sessionPath = lib.mkIf (hasRust || hasGo) [ "$HOME/.local/bin" ];
      packages =
        with pkgs;
        [ lspmux ] ++ lib.optionals hasGo [ gopls ] ++ lib.optionals hasRust [ rustAnalyzerMux ];
      file.".local/bin/rust-analyzer" = lib.mkIf hasRust {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${pkgs.lspmux}/bin/lspmux client "$@"
        '';
      };
      sessionVariables = {
        LSPMUX_SOCKET = socket;
      };
    };

    xdg.configFile."lspmux/config.toml".text = ''
      instance_timeout = 300
      gc_interval = 10
      listen = "${socket}"
      connect = "${socket}"
      log_filters = "info"
      pass_environment = ["*", "!WINDOWID", "!ALACRITTY_*", "!KITTY_WINDOW_ID", "!DESKTOP_STARTUP_ID", "!CMD_DURATION_MS", "!ZELLIJ_*", "!NVIM*", "!VIM*", "!MYVIMRC", "!OPENCODE*", "!AGENT", "!_", "!SHLVL", "!OLDPWD"]
    '';

    systemd.user.services.lspmux = lib.mkIf hasRust {
      Unit = {
        Description = "lspmux server (shared rust-analyzer)";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${socket}";
        ExecStart = "${pkgs.lspmux}/bin/lspmux server";
        Restart = "always";
        RestartSec = "5s";
        Environment = [
          "PATH=/home/joao/.nix-profile/bin:/home/joao/.local/bin:/home/joao/.cargo/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
        PassEnvironment = [
          "PATH"
          "PKG_CONFIG_PATH"
          "RUST_SRC_PATH"
          "CARGO_HOME"
          "RUSTUP_HOME"
          "RUSTUP_TOOLCHAIN"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
