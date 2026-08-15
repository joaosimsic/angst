{ host, lib }:

let
  defaultFontFamily = "JetBrainsMono Nerd Font";
in
rec {
  renderDomainOutputsFor =
    themeName:
    let
      themesLib = host.scan.themes;
      checkHelpers = import ../checks/theme/assertions.nix {
        inherit lib;
        theme = themesLib.get themeName;
        inherit themeName;
      };
      domainRendererPaths = map (e: "${e.path}/render.nix") (
        lib.filter (e: e.hasRender or false) host.scan.domains.homeEntries
      );
    in
    lib.concatLists (
      map (
        path:
        let
          render = import path;
        in
        render (
          lib.filterAttrs (name: _: builtins.hasAttr name (lib.functionArgs render)) {
            inherit
              lib
              themesLib
              themeName
              checkHelpers
              ;
            fontFamily = defaultFontFamily;
            monitors = host.monitors or { };
            db = host.db or { };
            sshAgent = host.sshAgent or { };
            homeDirectory = "/home/${host.username}";
          }
        )
      ) domainRendererPaths
    );

  renderDomainOutputFor =
    themeName: outputPath:
    let
      matches = lib.filter (output: output.path == outputPath) (renderDomainOutputsFor themeName);
    in
    if matches == [ ] then
      throw "Unknown domain render output: ${outputPath}"
    else
      (builtins.head matches).text;
}
