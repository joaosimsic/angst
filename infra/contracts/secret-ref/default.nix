let
  types = import ../../lib/types.nix;
  fs = import ../../lib/fs.nix;
  inventoryMod = import ./inventory.nix;
  validateMod = import ./validate.nix;
  leakMod = import ./leak.nix;

  secretsRoot = ../../../secrets;
  hasSecretsDir = builtins.pathExists secretsRoot;

  inventory = inventoryMod.mk {
    hasDir = hasSecretsDir;
    entries = if hasSecretsDir then fs.walkDir secretsRoot else [ ];
  };

  validation = validateMod.mk inventory;
in
{
  inherit hasSecretsDir;

  inherit (inventory)
    inventoryResult
    secretSlugs
    secretFiles
    secretInventory
    isInventoryEmpty
    inventoryWarn
    checkInventory
    ;

  inherit (validation)
    checkSecretRef
    isSecretRef
    isKnownSecretRef
    checkSecretRefsOnly
    checkSecretRefsIn
    ;

  SecretRef = ref: types.unwrap (validation.checkSecretRef ref);

  assertSecretRefsOnly = data: types.unwrap (validation.checkSecretRefsOnly data);

  assertSecretRefsIn = args: types.unwrap (validation.checkSecretRefsIn args);

  inherit (leakMod) checkNoKnownSecrets;

  assertNoKnownSecrets =
    secrets: message: dataJson:
    types.unwrap (leakMod.checkNoKnownSecrets secrets message dataJson);
}
