let
  error = import ../../lib/error.nix;

  throwError =
    message: context:
    error.throwError {
      kind = "SecretRef";
      inherit message context;
    };

  duplicateCause = duplicate: {
    kind = "SecretRef";
    message = "slug `${duplicate.slug}` maps to multiple files";
    context = { inherit (duplicate) files; };
  };
in
{
  inherit throwError;

  throwBadRef = context: throwError "`ref` must be a non-empty string" context;

  throwUnknownRef =
    context: ref:
    throwError "unknown `ref`, no such slug under secrets/ ref=${builtins.toJSON ref}" context;

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
    error.throwError {
      kind = "SecretRef";
      message = "duplicate slug maps to multiple files";
      causes = map duplicateCause duplicates;
    };

  throwSecretFields =
    context: throwError "checkSecretRefsIn: `secretFields` must be a list of non-empty strings" context;

  throwMissingInventory = context: throwError "secrets/ directory missing, no inventory" context;
}
