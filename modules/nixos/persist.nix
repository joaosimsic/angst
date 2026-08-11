{
  persist,
  username,
  persistDirs,
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
        "/etc/ssh"
      ];
      files = [
        "/etc/machine-id"
      ];
      users.${username} = {
        directories = persist.homeDirs ++ persistDirs;
      };
    };
  };
}
