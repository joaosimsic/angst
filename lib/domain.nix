{
  config,
  lib,
  pkgs,
  flakeSelf,
  repoPath,
  hostName,
  ...
}:

let
  cfg = config.domainConfig;

  angstSrc = lib.cleanSourceWith {
    src = flakeSelf;
    filter =
      path: _:
      let
        base = baseNameOf path;
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
      ${builtins.readFile ../scripts/seed-angst-repo.sh}
    '';

    home.activation.renderDomainConfigs = lib.hm.dag.entryAfter [ "seedAngstRepo" ] ''
      ANGST_REPO=${lib.escapeShellArg hostSrc}
      JSON_DATA=$(${lib.getBin pkgs.nix}/bin/nix eval --impure \
        "${flakeSelf}#lib.renderDomainOutputsFor" \
        --apply "f: builtins.toJSON (map (o: { path = o.path; text = o.text; }) (f \"${hostName}\" \"${config.theme}\"))" \
        --raw 2>/dev/null) || true

      if [ -n "$JSON_DATA" ] && [ "$JSON_DATA" != "[]" ]; then
        while IFS= read -r path; do
          [ -n "$path" ] || continue
          output="${angstDst}/$path"
          mkdir -p "$(dirname "$output")"
          echo "$JSON_DATA" | ${lib.getBin pkgs.jq}/bin/jq -r \
            ".[] | select(.path == \"$path\") | .text" > "$output"
          chmod u+w "$output"
          echo "angst: rendered $path"
        done < <(echo "$JSON_DATA" | ${lib.getBin pkgs.jq}/bin/jq -r '.[] | .path')
      fi
    '';
  };
}
