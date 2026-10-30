{ lib, themeSys }:

let
  t = import "../core/types.nix" { inherit lib; };

  inherit (import "../core/evalSchema.nix" { inherit lib; }) evalSchema;

  hostType = t.enum [
    "nixos"
    "home"
  ];

  architecture = t.enum [
    "x86_64-linux"
  ];

  monitorType = t.set {
    name = t.str;
    resolution = t.str;
    refreshRate = t.int;
    position = t.option t.str;
  };

  gitIdentity = t.set {
    name = t.str;
    email = t.str;
  };

  sshHost = t.set {
    host = t.str;
    hostName = t.str;
    user = t.str;
    identityFile = t.sty;
    extraOptions = t.option t.attrsOf t.str;
  };

  ftpMount = t.set {
    mountPoint = t.str;
    remotePath = t.option t.str;
    secretFile = t.str;
  };

  diskLayout = t.set {
    state = t.str;
    data = t.str;
  };

  schema = {
    type = hostType;

    architecture = t.option architecture;

    hostname = t.option t.str;
    username = t.option t.str;
    password = t.str;

    theme = mkOption {
      type = types.enum (builtins.attrNames themeSys.themes);
      inherit (themeSys) default;
    };

    monitors = t.option t.attrsOf monitorType;

    profiles = mkOption {
      type = types.listOf types.str;
      default = [ "base" ];
    };

    toolchains = mkOption {
      type = types.either (types.enum [ "*" ]) (types.listOf types.str);
      default = "*";
    };

    env = t.option t.attrsOf t.str;

    git = t.attrsOf gitIdentity;

    ssh = t.option t.attrsOf sshHost;

    ftp = t.option t.attrsOf ftpMount;

    diskLayout = t.option diskLayout;

    nixosConfiguration = t.option t.deferredModule;

    homeConfiguration = t.option t.deferredModule;

    browser = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  validate = set: evalSchema schema set;
in
{
  inherit schema validate;
}
