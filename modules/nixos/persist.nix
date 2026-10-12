{
  persist,
  username,
  lib,
  homeDirectory ? "/home/${username}",
  enabledFeatures ? [ ],
}:

let
  featureData = import ./persist-features.nix;

  featureEntries = lib.concatMap (id: featureData.features.${id} or [ ]) enabledFeatures;

  dataRoot = persist.dataRoot or null;
  durableEntries = builtins.filter (e: e.durable or false) featureEntries;
  stateEntries = builtins.filter (e: !(e.durable or false)) featureEntries;
  stateDirs = map (e: e.dir) stateEntries;

  bindMounts = lib.optionalAttrs (dataRoot != null) (
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
  ];
}
