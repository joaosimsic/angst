{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.editor.lspmux;
  socket = "/run/user/1000/lspmux.sock";
  goSocket = "/run/user/1000/gopls.sock";
  rustAnalyzerMux = pkgs.writeShellScriptBin "rust-analyzer-mux" ''
    exec ${pkgs.lspmux}/bin/lspmux client --server-path ${pkgs.rust-analyzer}/bin/rust-analyzer "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      lspmux
      gopls
      rustAnalyzerMux
    ];

    xdg.configFile."lspmux/config.toml".text = ''
      instance_timeout = 300
      gc_interval = 10
      listen = "${socket}"
      connect = "${socket}"
      log_filters = "info"
      pass_environment = ["*", "!WINDOWID", "!ALACRITTY_*", "!KITTY_WINDOW_ID", "!DESKTOP_STARTUP_ID"]
    '';

    systemd.user.services.lspmux = {
      Unit = {
        Description = "lspmux server (shared rust-analyzer)";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.lspmux}/bin/lspmux server";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = [
          "PATH=${pkgs.rust-analyzer}/bin:${pkgs.cargo}/bin:${pkgs.rustc}/bin:/home/joao/.cargo/bin:/home/joao/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          "RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}"
        ];
        PassEnvironment = [
          "PATH"
          "LD_LIBRARY_PATH"
          "RUST_SRC_PATH"
          "CARGO_HOME"
          "RUSTUP_HOME"
          "RUSTUP_TOOLCHAIN"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.gopls-daemon = {
      Unit = {
        Description = "gopls daemon (shared, -remote multiplex)";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.gopls}/bin/gopls -listen=unix;${goSocket} -listen.timeout=1h";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };

    home.sessionVariables = {
      LSPMUX_SOCKET = socket;
      GOPLS_REMOTE = "unix;${goSocket}";
    };
  };
}
