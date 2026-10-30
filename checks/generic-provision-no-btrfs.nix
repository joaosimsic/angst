{
  self,
  pkgs,
}:

let
  provision = self.apps.x86_64-linux.generic-provision.program;

  repo = pkgs.runCommand "angst-generic-test-repo" { } ''
    cp -a ${self}/. "$out"
    chmod -R u+w "$out"
  '';
in
pkgs.testers.runNixOSTest {
  name = "angst-generic-provision-no-btrfs";

  nodes.machine =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        btrfs-progs
        coreutils
        util-linux
      ];

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.succeed("mkdir -p /root/angst && cp -a ${repo}/. /root/angst")
    machine.succeed("sha256sum /root/angst/hosts/personal/generic/storage.nix > /tmp/storage.before")
    machine.succeed("findmnt -no FSTYPE / | grep -qx ext4")

    machine.succeed("cd /root/angst && ${provision} > /tmp/provision.out 2>&1")
    output = machine.succeed("cat /tmp/provision.out")
    assert "no btrfs partition found" in output, output
    assert "no disk changes made" in output, output

    machine.succeed("sha256sum /root/angst/hosts/personal/generic/storage.nix > /tmp/storage.after")
    machine.succeed("cmp /tmp/storage.before /tmp/storage.after")
    machine.succeed("findmnt -no FSTYPE / | grep -qx ext4")
    machine.fail("btrfs subvolume list /")
    machine.succeed("test ! -e /state")
  '';
}
