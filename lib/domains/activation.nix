{ lib }:

let
  inherit (lib)
    concatStringsSep
    removeSuffix
    hasSuffix
    attrNames
    foldl'
    optionalString
    ;

  mkDomainActivation =
    {
      lib,
      pkgs,
      configDir,
      meta,
      category,
      name,
      tokens,
      renderTemplate,
      homeDirectory,
    }:
    let
      hasXdg = (meta.xdg or null) != null;
      hasXdgFile = (meta.xdgFile or null) != null;
      hasConfigDir = builtins.pathExists configDir;

      
      findTemplates =
        dir: relPath:
        let
          entries = builtins.readDir dir;
        in
        foldl' (
          acc: entryName:
          let
            fullPath = "${dir}/${entryName}";
            entry = entries.${entryName};
            newRel =
              if relPath == "" then entryName else "${relPath}/${entryName}";
          in
          if entry == "directory" then
            acc ++ findTemplates fullPath newRel
          else if hasSuffix ".template" entryName then
            acc
            ++ [
              {
                rel = newRel;
                fullPath = fullPath;
                outputRel =
                  if relPath == "" then
                    removeSuffix ".template" entryName
                  else
                    "${relPath}/${removeSuffix ".template" entryName}";
              }
            ]
          else
            acc
        ) [ ] (attrNames entries);

      templateFiles = if hasConfigDir then findTemplates configDir "" else [ ];

      
      renderedTemplates = map (tpl: {
        inherit (tpl) outputRel;
        storePath = pkgs.writeText
          "domain-${category}-${name}-${builtins.replaceStrings [ "/" ] [ "-" ] tpl.outputRel}"
          (renderTemplate {
            inherit lib;
            templatePath = tpl.fullPath;
            inherit tokens;
          });
      }) templateFiles;

      
      templateDerivation =
        if renderedTemplates != [ ] then
          pkgs.runCommand "domain-${category}-${name}-rendered" { } (
            ''
              mkdir -p "$out"
            ''
            + concatStringsSep "\n" (
              map (tpl: ''
                mkdir -p "$(dirname "$out/${tpl.outputRel}")"
                cp ${tpl.storePath} "$out/${tpl.outputRel}"
              '') renderedTemplates
            )
          )
        else
          null;

      
      mkXdgScript =
        xdgName:
        ''
          # Domain ${category}/${name}: directory symlink
          if [ -d "/host${homeDirectory}/proj/angst" ]; then
            CFG_SRC="/host${homeDirectory}/proj/angst"
          else
            CFG_SRC="${homeDirectory}/.config/angst"
          fi

          DOMAIN_SRC="$CFG_SRC/domains/${category}/${name}/config"
          TARGET="${homeDirectory}/.config/${xdgName}"

          if [ ! -d "$DOMAIN_SRC" ]; then
            echo "domains.${category}.${name}: config source not found at $DOMAIN_SRC" >&2
            exit 1
          fi

          # Backup existing non-symlink directory
          if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
            $DRY_RUN_CMD mv "$TARGET" "$TARGET.hm-backup"
          fi

          $DRY_RUN_CMD mkdir -p "$(dirname "$TARGET")"
          $DRY_RUN_CMD ln -sfn "$DOMAIN_SRC" "$TARGET"
        ''
        + optionalString (templateDerivation != null) ''
          # Copy rendered templates into source dir (through symlink)
          $DRY_RUN_CMD cp -rfL ${templateDerivation}/* "$TARGET/"
          $DRY_RUN_CMD chmod -R u+w "$TARGET/"
        '';

      
      mkXdgFileScript =
        xdgFile:
        let
          hasTemplate = builtins.pathExists "${configDir}/${xdgFile}.template";
          renderedStorePath =
            if hasTemplate then (builtins.head renderedTemplates).storePath else null;
        in
        ''
          # Domain ${category}/${name}: single-file symlink
          if [ -d "/host${homeDirectory}/proj/angst" ]; then
            CFG_SRC="/host${homeDirectory}/proj/angst"
          else
            CFG_SRC="${homeDirectory}/.config/angst"
          fi

          DOMAIN_SRC="$CFG_SRC/domains/${category}/${name}/config"
          TARGET="${homeDirectory}/.config/${xdgFile}"

          # Ensure source dir exists
          $DRY_RUN_CMD mkdir -p "$DOMAIN_SRC"
        ''
        + optionalString hasTemplate ''
          # Copy rendered template into source dir
          $DRY_RUN_CMD cp -f ${renderedStorePath} "$DOMAIN_SRC/${xdgFile}"
          $DRY_RUN_CMD chmod u+w "$DOMAIN_SRC/${xdgFile}"
        ''
        + ''
          if [ ! -f "$DOMAIN_SRC/${xdgFile}" ]; then
            echo "domains.${category}.${name}: config file not found at $DOMAIN_SRC/${xdgFile}" >&2
            exit 1
          fi

          # Backup existing non-symlink
          if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
            $DRY_RUN_CMD mv "$TARGET" "$TARGET.hm-backup"
          fi

          $DRY_RUN_CMD mkdir -p "$(dirname "$TARGET")"
          $DRY_RUN_CMD ln -sf "$DOMAIN_SRC/${xdgFile}" "$TARGET"
        '';

      activationScript =
        if hasXdg then
          mkXdgScript meta.xdg
        else if hasXdgFile then
          mkXdgFileScript meta.xdgFile
        else
          "";
    in
    if !hasConfigDir || (!hasXdg && !hasXdgFile) then
      { }
    else
      {
        home.activation."domain-${category}-${name}" =
          lib.hm.dag.entryAfter [ "seedAngstRepo" "writeBoundary" ] activationScript;
      };
in
{
  inherit mkDomainActivation;
}
