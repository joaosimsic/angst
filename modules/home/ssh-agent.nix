{
  config,
  lib,
  pkgs,
  sshAgent,
  ...
}:

let
  cfg = config.angst.sshAgent;

  resolve = k: lib.replaceStrings [ "~" ] [ config.home.homeDirectory ] k;

  keys = map resolve cfg.keys;

  hasKeys = builtins.any (k: builtins.pathExists k) keys;

  sshAddScript = pkgs.writeShellApplication {
    name = "ssh-add-keys";
    runtimeInputs = [ pkgs.openssh pkgs.gnugrep pkgs.gawk ];
    text = ''
      for key in ${toString (map lib.escapeShellArg keys)}; do
        [ -f "$key" ] || continue
        fp="$(ssh-keygen -lf "$key" | awk '{print $2}')"
        ssh-add -l 2>/dev/null | grep -q "$fp" && continue
        ssh-add "$key" 2>/dev/null || true
      done
    '';
  };
in
{
  options.angst.sshAgent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = sshAgent.enable or true;
      description = "Start a persistent SSH agent and load configured keys at login";
    };

    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = sshAgent.keys or [ "~/.ssh/id_ed25519" "~/.ssh/id_rsa" ];
      description = "Private key paths to load into the SSH agent";
    };
  };

  config = lib.mkIf (cfg.enable && hasKeys) {
    systemd.user.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent.socket";

    systemd.user.services.ssh-agent = {
      Unit.Description = "Persistent SSH agent";
      Service.ExecStart = "${pkgs.openssh}/bin/ssh-agent -a %t/ssh-agent.socket -D";
      Service.Restart = "on-failure";
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.ssh-add = {
      Unit = {
        Description = "Add SSH keys to agent";
        Wants = [ "ssh-agent.service" ];
        After = [ "ssh-agent.service" ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "SSH_ASKPASS_REQUIRE=force"
          "SSH_ASKPASS=${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass"
        ];
        ExecStart = "${sshAddScript}/bin/ssh-add-keys";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
