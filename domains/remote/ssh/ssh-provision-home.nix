{
  config,
  lib,
  hostType,
  userConfig,
  flakeSelf,
  runtime,
  hostScopes ? [ ],
  ...
}:

let
  sshEnabled = config.domains.remote.ssh.enable;
  prov = runtime.sshKeyProvision {
    inherit (userConfig) username homeDirectory;
    secretsDir = "${flakeSelf}/secrets/ssh";
    scopes = hostScopes;
  };
in
{
  config = lib.mkIf (sshEnabled && hostType != "nixos") {
    home.activation.angstProvisionSshKey =
      lib.hm.dag.entryBetween [ "angstProjectsSync" ] [ "writeBoundary" ]
        ''
          ${prov.bin}
        '';

    systemd.user.services.angst-provision-ssh-key = {
      Unit.Description = "angst: decrypt and install the shared scope SSH keys";
      Service = {
        Type = "oneshot";
        ExecStart = prov.bin;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
