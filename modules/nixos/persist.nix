{
  persist,
  username,
  lib,
  homeDirectory ? "/home/${username}",
  enabledFeatures ? [ ],
}:
{ pkgs, ... }:

let
  featureData = import ./persist-features.nix;

  featureEntries = lib.concatMap (id: featureData.features.${id} or [ ]) enabledFeatures;

  dataRoot = persist.dataRoot or null;
  durable = dataRoot != null;
  durableEntries = builtins.filter (e: e.durable or false) featureEntries;
  stateEntries = builtins.filter (e: !(e.durable or false)) featureEntries;
  stateDirs = map (e: e.dir) stateEntries;

  # Parent components of a home-relative path: ".local/share/keyrings" ->
  # [ ".local" ".local/share" ]; "projects" -> [ ].
  parentDirsOf =
    rel:
    let
      parts = lib.splitString "/" rel;
    in
    lib.genList (i: lib.concatStringsSep "/" (lib.take (i + 1) parts)) (lib.length parts - 1);

  durableParentDirs = lib.unique (
    lib.concatMap (e: parentDirsOf e.dir) (lib.optionals durable durableEntries)
  );

  # systemd creates bind-mount points (and their parents) as root; on a
  # reinstalled data partition the durable sources can also be root-owned.
  # Repair both so the user can actually read/write the persisted state.
  ownershipScript = pkgs.writeShellScript "angst-persist-ownership" (
    lib.concatLines (
      [
        "set -eu"
        "chown ${username} ${lib.escapeShellArg homeDirectory} 2>/dev/null || true"
        "install -d -o ${username} -m 0755 ${lib.escapeShellArg dataRoot} 2>/dev/null || true"
      ]
      ++ map (
        p: "install -d -o ${username} -m 0755 ${lib.escapeShellArg "${homeDirectory}/${p}"}"
      ) durableParentDirs
      ++ map (e: "install -d -o ${username} -m 0755 ${lib.escapeShellArg "${dataRoot}/${e.name}"}") (
        lib.optionals durable durableEntries
      )
      ++ map (e: "chown ${username} ${lib.escapeShellArg "${dataRoot}/${e.name}"}") (
        lib.optionals durable durableEntries
      )
      ++ map (e: "install -d -o ${username} -m 0755 ${lib.escapeShellArg "${homeDirectory}/${e.dir}"}") (
        lib.optionals durable durableEntries
      )
      ++ map (e: "chown ${username} ${lib.escapeShellArg "${homeDirectory}/${e.dir}"}") (
        lib.optionals durable durableEntries
      )
    )
  );

  bindMounts = lib.optionalAttrs durable (
    builtins.listToAttrs (
      map (e: {
        name = "${homeDirectory}/${e.dir}";
        value = {
          device = "${dataRoot}/${e.name}";
          fsType = "none";
          options = [ "bind" ];
          neededForBoot = e.neededForBoot or false;
        };
      }) durableEntries
    )
  );
in
{
  config = lib.mkMerge [
    (lib.mkIf persist.enable {
      environment.persistence."${persist.root}" = {
        hideMounts = true;
        directories = [
          "/var/log"
          "/var/lib/bluetooth"
          "/var/lib/nixos"
          "/var/lib/systemd/coredump"
          "/var/lib/NetworkManager"
          "/var/lib/alsa"
          "/etc/ssh"
          "/etc/NetworkManager/system-connections"
        ];
        files = [
          "/etc/machine-id"
        ];
        users.${username} = {
          directories =
            stateDirs ++ lib.optionals (dataRoot == null) (map (e: e.dir) durableEntries) ++ persist.homeDirs;
          files = persist.homeFiles or [ ];
        };
      };
    })
    (lib.mkIf (persist.enable && bindMounts != { }) {
      fileSystems = bindMounts;
    })
    (lib.mkIf (persist.enable && durable && durableEntries != [ ]) {
      systemd.services.angst-persist-ownership = {
        description = "angst: ensure durable persistent dirs are owned by ${username}";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        before = [ "home-manager-${username}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = ownershipScript;
        };
      };
    })
  ];
}
