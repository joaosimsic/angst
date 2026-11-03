let
  contextSuffix =
    context:
    let
      names = builtins.attrNames context;
      rendered = builtins.concatStringsSep " " (
        map (name: "${name}=${builtins.toJSON context.${name}}") names
      );
    in
    if names == [ ] then "" else " (${rendered})";

  throwError = message: context: throw "${message}${contextSuffix context}";
in
{
  inherit throwError;

  throwBadRef = context: throwError "SecretRef: `ref` must be a non-empty string" context;

  throwUnknownRef =
    context: ref:
    throwError "SecretRef: unknown `ref`, no such slug under secrets/ ref=${builtins.toJSON ref}" context;

  throwField =
    context: throwError "secret field must be `SecretRef { ref }`, never a plain string" context;

  throwMisplaced =
    context: throwError "SecretRef misplaced: allowed only under secret fields" context;

  throwUnsupported = context: throwError "SecretRef edge rejected: unsupported value type" context;

  throwLeak =
    context:
    throwError "plain secret value present in message/data; wrap as `SecretRef` instead" context;

  throwDuplicate =
    duplicates:
    throw "SecretRef: duplicate slug maps to multiple files duplicates=${builtins.toJSON duplicates}";

  throwSecretFields =
    context: throwError "checkSecretRefsIn: `secretFields` must be a list of non-empty strings" context;

  throwMissingInventory =
    context: throwError "SecretRef: secrets/ directory missing, no inventory" context;
}
