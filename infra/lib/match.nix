let
  logCodePattern = "([A-Z]+)[0-9]+$";

  slashPattern = ".*/.*";

  parseLogCode = code: if builtins.isString code then builtins.match logCodePattern code else null;

  logCodePrefix =
    code:
    let
      m = parseLogCode code;
    in
    if m == null then null else builtins.head m;

  hasSlash = v: builtins.isString v && builtins.match slashPattern v != null;
in
{
  inherit
    logCodePattern
    slashPattern
    parseLogCode
    logCodePrefix
    hasSlash
    ;
}
