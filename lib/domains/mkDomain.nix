{
  lib,
  pkgs,
}:

{
  category,
  name,
  path,
  spec,
}:

let
  err = msg: builtins.throw "domains/${category}/${name}/default.nix: ${msg}";

  allowedKeys = [
    "package"
    "xdg"
    "xdgFile"
    "customXdg"
    "description"
    "mutable"
  ];

  unknownKeys = builtins.filter (k: !builtins.elem k allowedKeys) (builtins.attrNames spec);

  package = spec.package or null;
  xdg = spec.xdg or null;
  xdgFile = spec.xdgFile or null;
  customXdg = spec.customXdg or false;
  description = spec.description or null;
  mutable = spec.mutable or [ ];

  isNonEmptyStr = v: builtins.isString v && v != "";
  isRelPath = v: builtins.isString v && !(lib.hasPrefix "/" v) && !(lib.hasPrefix "~" v) && !(lib.hasPrefix ".." v);
  isBasename = v: builtins.isString v && v != "" && !(lib.hasInfix "/" v);

  hasHomeFile = builtins.pathExists "${path}/home.nix";
  hasSystemFile = builtins.pathExists "${path}/system.nix";
  hasRenderFile = builtins.pathExists "${path}/render.nix";
  hasConfigDir = builtins.pathExists "${path}/config";

  checkModule =
    kind: file:
    let
      m = import file;
    in
    if !(builtins.isFunction m) && !(builtins.isAttrs m) then
      err "${kind} module '${file}' must be a function or attrset"
    else
      m;

  hasTarget = xdg != null || xdgFile != null || customXdg;
  hasHomeContent = hasHomeFile || hasRenderFile || hasConfigDir;

  configType = if hasConfigDir then (builtins.readDir path).config or null else null;
in
if unknownKeys != [ ] then
  err "unknown attribute(s): ${builtins.concatStringsSep ", " unknownKeys}. Valid attributes: ${builtins.concatStringsSep ", " allowedKeys}"
else if package != null && !(isNonEmptyStr package) then
  err "'package' must be a non-empty string"
else if package != null && !(builtins.hasAttr package pkgs) then
  err "'package' '${package}' does not exist in pkgs"
else if xdg != null && !(isRelPath xdg) then
  err "'xdg' must be a relative path (no leading '/', '~', or '..')"
else if xdgFile != null && !(isRelPath xdgFile) then
  err "'xdgFile' must be a relative path (no leading '/', '~', or '..')"
else if xdg != null && xdgFile != null then
  err "'xdg' and 'xdgFile' are mutually exclusive"
else if spec ? customXdg && !(builtins.isBool customXdg) then
  err "'customXdg' must be a bool"
else if !(isNonEmptyStr description) then
  err "'description' is required (non-empty string)"
else if !(builtins.isList mutable) || !(builtins.all isBasename mutable) then
  err "'mutable' must be a list of basenames (no '/')"
else if mutable != [ ] && !hasRenderFile then
  err "'mutable' requires a render.nix"
else if customXdg && !hasHomeFile then
  err "'customXdg = true' requires a home.nix module"
else if hasHomeContent && !hasTarget then
  err "must set one of 'xdg', 'xdgFile', or 'customXdg' for the home content (home.nix, render.nix, config/)"
else if package == null && !hasSystemFile && !hasTarget then
  err "domain is empty: declare a 'package', a 'system.nix', or a home placement target"
else if configType != "directory" && configType != null then
  err "'config' must be a directory"
else
  {
    inherit
      category
      name
      path
      ;
    meta = {
      inherit
        package
        xdg
        xdgFile
        customXdg
        description
        mutable
        ;
    };
    hasHome = hasHomeFile;
    home = if hasHomeFile then checkModule "home" "${path}/home.nix" else null;
    hasSystem = hasSystemFile;
    system = if hasSystemFile then checkModule "system" "${path}/system.nix" else null;
    hasRender = hasRenderFile;
    render = if hasRenderFile then checkModule "render" "${path}/render.nix" else null;
    inherit hasConfigDir;
    config = if hasConfigDir then "${path}/config" else null;
  }
