let
  logCodePattern = "([A-Z]+)[0-9]+$";

# is this the optimal way to detect a secret key?
  secretKeyPattern = ".*(secret|Secret|SECRET|token|Token|password|Password|passwd|private|Private|credential|Credential|apiKey|api_key|auth|Auth|decrypted|Decrypted).*";

  slashPattern = ".*/.*";

  parseLogCode = code: if builtins.isString code then builtins.match logCodePattern code else null;

  logCodePrefix =
    code:
    let
      m = parseLogCode code;
    in
    if m == null then null else builtins.head m;

  isSecretKeyName = name: builtins.isString name && builtins.match secretKeyPattern name != null;

  hasSlash = v: builtins.isString v && builtins.match slashPattern v != null;
in
{
  inherit
    logCodePattern
    secretKeyPattern
    slashPattern
    parseLogCode
    logCodePrefix
    isSecretKeyName
    hasSlash
    ;
}
