{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    _:
    let
      logger = import ./infra/logger/default.nix;
    in
    {
      lib.logger = {
        inherit (logger)
          checkLogCode
          logCodePrefix
          logCodes
          ;
        inherit (logger)
          checkLogLevel
          isLogLevel
          logLevels
          ;
        inherit (logger)
          SecretRef
          checkNoKnownSecrets
          hasSecretsDir
          ;
        inherit (logger)
          checkSecretRef
          checkSecretRefsIn
          checkSecretRefsOnly
          isKnownSecretRef
          isSecretRef
          ;
        inherit (logger)
          inventoryWarn
          isInventoryEmpty
          secretFiles
          secretInventory
          secretSlugs
          ;
        inherit (logger)
          diagnostic
          event
          render
          renderDiagnostic
          renderDiagnostics
          renderEvent
          throwDiagnostics
          toJSONL
          ;
      };
    };
}
