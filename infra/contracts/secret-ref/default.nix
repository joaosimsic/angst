let
  fs = import ../../lib/fs.nix;
  secretInventoryModule = import ./inventory.nix;
  secretRefValidationModule = import ./validate.nix;
  secretLeakModule = import ./leak.nix;

  secretsRoot = ../../../secrets;
  hasSecretsDir = builtins.pathExists secretsRoot;

  inventoryValue = secretInventoryModule.mkSecretInventory {
    hasDir = hasSecretsDir;
    entries = if hasSecretsDir then fs.walkDir secretsRoot else [ ];
  };

  validationValue = secretRefValidationModule.mkSecretRefValidation inventoryValue;
in
{
  inherit hasSecretsDir;

  inherit (inventoryValue)
    inventoryWarn
    isInventoryEmpty
    secretFiles
    secretInventory
    secretSlugs
    ;

  inherit (validationValue)
    checkSecretRef
    checkSecretRefsIn
    checkSecretRefsOnly
    isKnownSecretRef
    isSecretRef
    ;

  SecretRef = ref: validationValue.checkSecretRef ref;

  inherit (secretLeakModule) checkNoKnownSecrets;
}
