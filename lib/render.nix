{ cfg, lib }:

let
  fontsLib = import ./home/fonts.nix;
in rec {
  # hostName is accepted for API compat with existing callers (not used — cfg has everything)
  renderDomainOutputsFor = hostName: themeName:
    let
      themesLib = cfg.scan.themes;
      checkHelpers = import ./checks/theme/assertions.nix { inherit lib; theme = themesLib.get themeName; inherit themeName; };
      domainRendererPaths = map (e: "${e.path}/render.nix") (
        lib.filter (e: e.hasRender or false) cfg.scan.domains.homeEntries
      );
    in lib.concatLists (map (path: import path {
      inherit lib themesLib themeName checkHelpers fontsLib;
      fontFamily = fontsLib.defaultFamily;
      monitors = cfg.monitors or {};
      homeDirectory = "/home/${cfg.username}";
    }) domainRendererPaths);

  renderDomainOutputFor = hostName: themeName: outputPath:
    let
      matches = lib.filter (output: output.path == outputPath) (renderDomainOutputsFor hostName themeName);
    in if matches == [] then builtins.throw "Unknown domain render output: ${outputPath}"
      else (builtins.head matches).text;
}
