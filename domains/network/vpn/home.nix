{
  config,
  lib,
  pkgs,
  flakeSelf,
  runtime,
  userConfig,
  ...
}:
let
  cfg = config.domains.network.vpn;
  enabled = cfg.enable && cfg.openvpn.servers != { };
  names = builtins.attrNames cfg.openvpn.servers;
  provisionBin =
    (runtime.vpn-provision {
      secretsDir = "${flakeSelf}/${cfg.secretsDir}";
      inherit (cfg) destDir;
      inherit (userConfig) username homeDirectory;
      scopes = [
        "personal"
        "work"
      ];
    }).bin;
  provisionWrapper = pkgs.writeShellApplication {
    name = "angst-provision-vpn-home";
    runtimeInputs = with pkgs; [
      coreutils
      bash
    ];
    text = ''
      set -euo pipefail
      if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
        dest="$XDG_RUNTIME_DIR/secrets/vpn"
      else
        dest="/run/user/$(id -u)/secrets/vpn"
        if [ ! -d "/run/user/$(id -u)" ]; then
          dest="$HOME/.cache/angst/vpn"
        fi
      fi
      if [ "${cfg.destDir}" != "/run/secrets/vpn" ]; then
        dest="${cfg.destDir}"
      fi
      mkdir -p "$dest"
      chmod 0700 "$dest"
      exec ${provisionBin} --secrets-dir "${flakeSelf}/${cfg.secretsDir}" --dest-dir "$dest" --user "${userConfig.username}" --home "${userConfig.homeDirectory}" --scopes personal,work
    '';
  };
  mkVpnService =
    n: srv:
    let
      upScript = pkgs.writeShellScript "vpn-${n}-up" srv.up;
      downScript = pkgs.writeShellScript "vpn-${n}-down" srv.down;
      wrapper = pkgs.writeShellApplication {
        name = "angst-vpn-${n}";
        runtimeInputs = with pkgs; [
          openvpn
          coreutils
          bash
        ];
        text =
          let
            base =
              if srv.config != "" then
                "exec openvpn ${srv.config}"
              else
                ''exec openvpn --config "$dest/${n}.ovpn"''
                + lib.optionalString (
                  srv.authUserPass != null && builtins.isString srv.authUserPass
                ) ''--auth-user-pass "${srv.authUserPass}"'';
            extra = lib.concatStringsSep " " (
              lib.optional (srv.up != "") ''--up "${upScript}"''
              ++ lib.optional (srv.down != "") ''--down "${downScript}"''
            );
          in
          ''
            set -euo pipefail
            if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
              dest="$XDG_RUNTIME_DIR/secrets/vpn"
            else
              dest="/run/user/$(id -u)/secrets/vpn"
            fi
            if [ "${cfg.destDir}" != "/run/secrets/vpn" ]; then
              dest="${cfg.destDir}"
            fi
            ${lib.optionalString (
              srv.config == ""
            ) ''[ -f "$dest/${n}.ovpn" ] || { echo "vpn ${n}: missing $dest/${n}.ovpn" >&2; exit 1; }''}
            ${base} ${extra}
          '';
      };
    in
    {
      Unit = {
        Description = "OpenVPN ${n} (user, ephemeral)";
        After = [
          "network-online.target"
          "angst-provision-vpn.service"
        ];
        Wants = [ "network-online.target" ];
        Requires = [ "angst-provision-vpn.service" ];
      };
      Service = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        ExecStart = "${wrapper}/bin/angst-vpn-${n}";
      };
      Install = lib.mkIf srv.autoStart { WantedBy = [ "default.target" ]; };
    };
in
{
  config = lib.mkIf enabled {
    home.activation.angstProvisionVpn = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${provisionWrapper}/bin/angst-provision-vpn-home || true
    '';
    systemd.user.services = {
      angst-provision-vpn = {
        Unit.Description = "angst: decrypt VPN .ovpn + creds (ephemeral %t/secrets/vpn)";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${provisionWrapper}/bin/angst-provision-vpn-home";
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
    // lib.listToAttrs (
      map (n: lib.nameValuePair "angst-vpn-${n}" (mkVpnService n cfg.openvpn.servers.${n})) names
    );
  };
}
