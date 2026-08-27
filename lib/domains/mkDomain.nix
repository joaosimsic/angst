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
  isRelPath =
    v:
    builtins.isString v && !(lib.hasPrefix "/" v) && !(lib.hasPrefix "~" v) && !(lib.hasPrefix ".." v);
  isBasename = v: builtins.isString v && v != "" && !(lib.hasInfix "/" v);

  hasHomeFile = builtins.pathExists (path + "/home.nix");
  hasSystemFile = builtins.pathExists (path + "/system.nix");
  hasRenderFile = builtins.pathExists (path + "/render.nix");
  hasConfigDir = builtins.pathExists (path + "/config");
  hasHealthcheck = builtins.pathExists (path + "/healthcheck.nix");

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

  checks = [
    {
      cond = unknownKeys != [ ];
      msg = "unknown attribute(s): ${builtins.concatStringsSep ", " unknownKeys}. Valid attributes: ${builtins.concatStringsSep ", " allowedKeys}";
    }
    {
      cond = package != null && !(isNonEmptyStr package);
      msg = "'package' must be a non-empty string";
    }
    {
      cond = package != null && !(builtins.hasAttr package pkgs);
      msg = "'package' '${package}' does not exist in pkgs";
    }
    {
      cond = xdg != null && !(isRelPath xdg);
      msg = "'xdg' must be a relative path (no leading '/', '~', or '..')";
    }
    {
      cond = xdgFile != null && !(isRelPath xdgFile);
      msg = "'xdgFile' must be a relative path (no leading '/', '~', or '..')";
    }
    {
      cond = xdg != null && xdgFile != null;
      msg = "'xdg' and 'xdgFile' are mutually exclusive";
    }
    {
      cond = spec ? customXdg && !(builtins.isBool customXdg);
      msg = "'customXdg' must be a bool";
    }
    {
      cond = !(isNonEmptyStr description);
      msg = "'description' is required (non-empty string)";
    }
    {
      cond = !(builtins.isList mutable) || !(builtins.all isBasename mutable);
      msg = "'mutable' must be a list of basenames (no '/')";
    }
    {
      cond = mutable != [ ] && !hasRenderFile;
      msg = "'mutable' requires a render.nix";
    }
    {
      cond = customXdg == true && !hasHomeFile;
      msg = "'customXdg = true' requires a home.nix module";
    }
    {
      cond = hasHomeContent && !hasTarget;
      msg = "must set one of 'xdg', 'xdgFile', or 'customXdg' for the home content (home.nix, render.nix, config/)";
    }
    {
      cond = package == null && !hasSystemFile && !hasTarget;
      msg = "domain is empty: declare a 'package', a 'system.nix', or a home placement target";
    }
    {
      cond = configType != "directory" && configType != null;
      msg = "'config' must be a directory";
    }
  ];

  firstError = lib.foldl' (
    acc: c:
    if acc != null then
      acc
    else if c.cond then
      c.msg
    else
      null
  ) null checks;

  body = {
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
    home = if hasHomeFile then checkModule "home" (path + "/home.nix") else null;
    hasSystem = hasSystemFile;
    system = if hasSystemFile then checkModule "system" (path + "/system.nix") else null;
    hasRender = hasRenderFile;
    render = if hasRenderFile then checkModule "render" (path + "/render.nix") else null;
    inherit hasConfigDir;
    config = if hasConfigDir then path + "/config" else null;
    inherit hasHealthcheck;
    healthcheck =
      if hasHealthcheck then checkModule "healthcheck" (path + "/healthcheck.nix") else null;
  };
in
if firstError != null then err firstError else body
