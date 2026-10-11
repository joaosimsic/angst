{
  persist,
  username,
  persistDirs,
  persistFiles ? [ ],
  lib,
}:

{
  config = lib.mkIf persist.enable {
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
        directories = persist.homeDirs ++ persistDirs;
        files = persistFiles;
      };
    };
  };
}
