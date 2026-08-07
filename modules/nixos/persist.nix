{ persist, username, persistDirs, lib }:

{
  config = lib.mkIf persist.enable {
    environment.persistence."${persist.root}" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        # "/etc/ssh"  -- REMOVED for testing
      ];
      files = [
        "/etc/machine-id"
      ];
      users.${username} = {
        directories = map (d: "/home/${username}/${d}") (
          persist.homeDirs ++ persistDirs
        );
      };
    };
  };
}
