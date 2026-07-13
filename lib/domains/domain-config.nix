{
  config,
  lib,
  flakeSelf,
  repoPath,
  ...
}:

let
  cfg = config.domainConfig;

  angstSrc = lib.cleanSourceWith {
    src = flakeSelf;
    filter =
      path: _:
      let
        base = builtins.baseNameOf path;
      in
      base != ".git" && base != "result" && !(lib.hasSuffix ".qcow2" base);
  };

  hostSrc = "/host${config.home.homeDirectory}/${repoPath}";
  angstDst = cfg.sourceDir;
in
{
  options.domainConfig = {
    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/angst";
      description = "Path to the config source repository root";
    };
  };

  
  config = lib.mkIf (!lib.hasPrefix "/host" (toString flakeSelf)) {
    home.activation.seedAngstRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      HOST_SRC=${lib.escapeShellArg hostSrc}
      ANGST_SRC=${lib.escapeShellArg angstSrc}
      ANGST_DST=${lib.escapeShellArg angstDst}
      ${builtins.readFile ../../scripts/seed-angst-repo.sh}
    '';
  };
}
