{
  host,
  lib,
}:

let
  hasAppSecrets = (host.appSecrets or [ ]) != [ ];
  hasHomeHostSecrets = (host.hostSecrets or [ ]) != [ ] && host.type != "nixos";

  appSecretsModule = import ./home/app-secrets.nix;
  hostSecretsModule = import ./home/host-secrets.nix;
in
{
  homeModules =
    lib.optional hasAppSecrets appSecretsModule ++ lib.optional hasHomeHostSecrets hostSecretsModule;
}
