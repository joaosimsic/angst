{
  inputs,
  themesLib,
  domain,
  decl,
  self ? null,
  pkgsOverride ? null,
  tcIndexOverride ? null,
  domainsLibOverride ? null,
}:

let
  lib = inputs.nixpkgs.lib;

  system = decl.system or "x86_64-linux";
  pkgs =
    if pkgsOverride != null then
      pkgsOverride
    else
      import inputs.nixpkgs {
        inherit system;
        config = import ./nixpkgs-config.nix;
      };

  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix") (
      builtins.readDir _toolchainDir
    )
  );
  _importToolchain = import ./toolchain-import.nix { inherit lib; };
  _fenixPkgs =
    if inputs ? fenix && builtins.hasAttr system inputs.fenix.packages then
      inputs.fenix.packages.${system}
    else
      null;
  _tcIndex =
    if tcIndexOverride != null then
      tcIndexOverride
    else
      lib.listToAttrs (
        map (
          f:
          let
            name = lib.removeSuffix ".nix" f;
            fullArgs = {
              inherit lib pkgs;
              fenix = _fenixPkgs;
            };
          in
          {
            inherit name;
            value = _importToolchain (_toolchainDir + "/${f}") fullArgs;
          }
        ) _rawFiles
      );
  _allTCs = builtins.attrValues _tcIndex;

  domainsScan =
    if domainsLibOverride != null then
      null
    else
      import ./domains/scan.nix {
        inherit lib pkgs;
        domainsPath = if self != null then self + "/domains" else ../domains;
      };
  domainsModule = import ./domains/module.nix { };
  domainsLib =
    if domainsLibOverride != null then domainsLibOverride else domainsScan // domainsModule;

  _toolchains = decl.toolchains or "*";
  _bareNames = builtins.attrNames _tcIndex;
  _selectedTCs =
    if _toolchains == "*" then
      _allTCs
    else if builtins.isList _toolchains then
      let
        unknown = builtins.filter (n: !builtins.elem n _bareNames) _toolchains;
      in
      if unknown != [ ] then
        throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " _bareNames}"
      else
        map (n: _tcIndex.${n}) _toolchains
    else
      throw "toolchains must be \"*\" or a list";

  validScopes = [
    "personal"
    "work"
  ];

  reservedHostSecretNames = [
    "apps"
    "password"
    "ssh"
    "projects"
    "db"
    "vpn"
    "ftp"
    "hosts"
  ];

  rawSecrets = decl.secrets or { };

  secretScopes =
    if !(builtins.isAttrs rawSecrets) then
      throw "secrets: must be an attrset { scopes; password; apps; host; }, got ${builtins.typeOf rawSecrets}"
    else if !(builtins.isList (rawSecrets.scopes or [ ])) then
      throw "secrets.scopes: must be a list"
    else
      let
        scopes = rawSecrets.scopes or [ ];
        unknown = builtins.filter (s: !builtins.elem s validScopes) scopes;
      in
      if unknown != [ ] then
        throw "secrets.scopes: unknown scope(s) ${builtins.concatStringsSep ", " unknown}; expected personal or work"
      else if lib.unique scopes != scopes then
        throw "secrets.scopes: scopes must be unique"
      else
        scopes;

  parseSecretRef =
    kind: raw:
    if !(builtins.isString raw) then
      throw "secrets.${kind}: entries must be strings like \"personal/name\", got ${builtins.typeOf raw}"
    else
      let
        parts = lib.splitString "/" raw;
      in
      if builtins.length parts != 2 then
        throw "secrets.${kind}: '${raw}' must be <scope>/<name>"
      else
        let
          scope = builtins.elemAt parts 0;
          name = builtins.elemAt parts 1;
        in
        if !(builtins.elem scope validScopes) then
          throw "secrets.${kind}: '${raw}' has invalid scope '${scope}'"
        else if !(builtins.elem scope secretScopes) then
          throw "secrets.${kind}: '${raw}' uses scope '${scope}' not present in secrets.scopes"
        else if name == "" || name == "." || name == ".." || lib.hasInfix "/" name then
          throw "secrets.${kind}: '${raw}' has an invalid name"
        else if kind == "host" && builtins.elem name reservedHostSecretNames then
          throw "secrets.host: '${raw}' uses reserved secrets directory '${name}'"
        else
          {
            inherit scope name raw;
          };

  appSecretRefs = map (parseSecretRef "apps") (rawSecrets.apps or [ ]);
  hostSecretRefs = map (parseSecretRef "host") (rawSecrets.host or [ ]);

  passwordSecret =
    let
      name = rawSecrets.password or null;
    in
    if name == null then
      null
    else if !(builtins.isString name) then
      throw "secrets.password: must be a string name, got ${builtins.typeOf name}"
    else if name == "" || name == "." || name == ".." || lib.hasInfix "/" name then
      throw "secrets.password: '${name}' must be a plain name, not a path"
    else if secretScopes == [ ] then
      throw "secrets.password: requires at least one entry in secrets.scopes"
    else
      name;
in

{
  inherit _tcIndex _allTCs _selectedTCs;

  host = {
    inherit system pkgs;
    hostname = decl.hostname or "nixos";
    username = decl.username or "user";
    theme = decl.theme or "monochrome";

    password =
      decl.password
        or "$6$7BqkEtUqOq/ylZb5$0dij1Cb/ykQJ8Vqt7SEJ7MMD77gn/ZW0LuLGo6tjU4e3rQcIyoH7q878EU2xXB9Suwh2bV/d/kpWeVl/nbsoe.";
    monitors = decl.monitors or { };
    db =
      let
        raw = decl.db or [ ];
        isList = builtins.isList raw;
        isAttrs = builtins.isAttrs raw;
      in
      if isList then
        raw
      else if isAttrs && raw == { } then
        [ ]
      else if isAttrs && raw == { connections = { }; } then
        [ ]
      else if isAttrs then
        throw "db: inline db.connections removed — use db = [\"personal/slug\" \"work/slug\" …] + vault tarball (secrets/db/<scope>.tar.age) with <slug>.json; see openwiki/secrets.md#db-store (got ${builtins.toJSON raw})"
      else
        throw "db: must be a list of scoped slugs like [\"personal/my-pg\" \"work/analytics\"], got ${builtins.typeOf raw}";
    profiles = decl.profiles or [ "base" ];
    toolchains = _toolchains;
    toolchainNames = if _toolchains == "*" then _bareNames else _toolchains;
    extraNixos = decl.nixos or { };
    extraHome = decl.home or { };
    env = decl.env or { };
    sshAgent = decl.sshAgent or { };
    git = decl.git or { };
    ssh = decl.ssh or { };
    ftp = decl.ftp or { };
    shell = decl.shell or "";
    persist = {
      root = "/persist";
      homeDirs = [ ];
      homeFiles = [ ];
      enable = false;
    }
    // (decl.persist or { });
    projects = decl.projects or [ ];
    type = decl.type or "nixos";
    inherit domain;

    scopes = secretScopes;
    inherit passwordSecret;
    appSecrets = map (r: r.raw) appSecretRefs;
    hostSecrets = map (r: r.raw) hostSecretRefs;

    toolchainModules = _selectedTCs;

    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or [ ]) _selectedTCs);
      treesitter = import ./treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) _selectedTCs);
      };
      editorLsp = lib.foldl' (acc: t: acc // (t.toolchains.editor.lsp or { })) { } _selectedTCs;
    };
  };
}
