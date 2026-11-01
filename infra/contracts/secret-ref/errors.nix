let
  types = import ../../lib/types.nix;

  err =
    message: context:
    types.err {
      kind = "secret";
      inherit message context;
    };
in
{
  inherit err;

  badRef = context: err "SecretRef: `ref` must be a non-empty string" context;

  unknownRef =
    context: ref:
    err "SecretRef: unknown `ref`, no such slug under secrets/" (context // { inherit ref; });

  field = context: err "secret field must be `SecretRef { ref }`, never a plain string" context;

  misplaced = context: err "SecretRef misplaced: allowed only under secret fields" context;

  unsupported = context: err "SecretRef edge rejected: unsupported value type" context;

  leak =
    context: err "plain secret value present in message/data; wrap as `SecretRef` instead" context;

  duplicate = context: err "SecretRef: duplicate slug maps to multiple files" context;

  secretFields =
    context: err "checkSecretRefsIn: `secretFields` must be a list of non-empty strings" context;
}
