{
  lib,
  host,
  homeDirectory,
  enabledFeatures ? null,
}:

let
  inherit (host) persist;

  resolvedEnabledFeatures =
    if enabledFeatures != null then
      enabledFeatures
    else
      let
        profileEntries =
          (import ../profiles/default.nix {
            inherit lib;
            inherit (host) profiles scan;
          }).enabled;
        domainIds = map (
          e: if e.category == e.name then e.category else "${e.category}.${e.name}"
        ) profileEntries;
      in
      domainIds ++ map (n: "toolchain:${n}") (host.toolchainNames or [ ]);

  featureData = import ../modules/nixos/persist-features.nix;
  featureEntries = lib.concatMap (id: featureData.features.${id} or [ ]) resolvedEnabledFeatures;

  toHomePath = path: if lib.hasPrefix "/" path then path else "${homeDirectory}/${path}";

  homeRoots =
    if persist.enable or false then
      map toHomePath (map (e: e.dir) featureEntries ++ (persist.homeDirs or [ ]))
    else
      [ ];

  homeFiles = if persist.enable or false then map toHomePath (persist.homeFiles or [ ]) else [ ];

  storeRoots =
    if persist.enable or false then
      lib.optional (persist.root != null) persist.root
      ++ lib.optional ((persist.dataRoot or null) != null) persist.dataRoot
    else
      [ ];
in
{
  enabledFeatures = resolvedEnabledFeatures;
  inherit homeFiles;
  roots = lib.unique (homeRoots ++ storeRoots);
}
