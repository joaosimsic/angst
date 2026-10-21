{
  self,
  pkgs,
}:

let
  generic = self.nixosConfigurations.generic;

  genericToplevel = generic.config.system.build.toplevel;
  genericKernel = "${generic.config.system.build.kernel}/${generic.config.system.boot.loader.kernelFile}";
  genericInitrd = "${generic.config.system.build.initialRamdisk}/${generic.config.system.boot.loader.initrdFile}";

  provision = self.apps.x86_64-linux.generic-provision.program;
  switch = self.apps.x86_64-linux.generic-switch.program;

  repo = pkgs.runCommand "angst-generic-provision-repo" { } ''
    cp -a ${self}/. "$out"
    chmod -R u+w "$out"
  '';

  inputPaths = map (input: input.outPath) (builtins.attrValues self.inputs);
in
pkgs.testers.runNixOSTest {
  name = "angst-generic-provision";

  qemu.forceAccel = true;
  globalTimeout = 60 * 60;

  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation = {
        memorySize = 8192;
        cores = 4;
        diskSize = 2048;
        useDefaultFilesystems = false;
        rootDevice = "/dev/vdc";
        useNixStoreImage = true;
        writableStore = true;
        useEFIBoot = true;
        additionalPaths = [
          genericToplevel
          repo
          provision
          switch
        ]
        ++ inputPaths;
        emptyDiskImages = [
          40960
          256
          256
        ];
      };

      systemd.repart.partitions."00-root" = {
        Type = "linux-generic";
        Format = "btrfs";
        Label = "nixos";
      };

      boot.initrd = {
        supportedFilesystems = [ "btrfs" ];
        systemd = {
          enable = true;
          repart = {
            enable = true;
            device = "/dev/vdc";
            empty = "allow";
          };
        };
      };

      virtualisation.fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "btrfs";
      };

      system.extraDependencies = [
        genericToplevel
        repo
        provision
        switch
      ]
      ++ inputPaths;

      environment.systemPackages = with pkgs; [
        btrfs-progs
        coreutils
        dosfstools
        efibootmgr
        findutils
        gptfdisk
        gnugrep
        kexec-tools
        util-linux
      ];
    };

  testScript = { nodes, ... }: ''
    import shlex
    import time

    def run(cmd):
        status, output = machine.execute(cmd)
        print(output)
        assert status == 0, output
        return output

    def checksum(path):
        return machine.succeed(f"sha256sum {shlex.quote(path)}").split()[0]

    machine.wait_for_unit("multi-user.target")
    machine.succeed("test -e ${genericToplevel}")
    machine.succeed("mkdir -p /root/angst")
    machine.succeed("cp -a ${repo}/. /root/angst")
    machine.succeed("mkdir -p /root/angst/hosts/personal/generic")

    # Source ESP shared with a Windows-like bootloader.
    machine.succeed("sgdisk --zap-all /dev/vde")
    machine.succeed("sgdisk -n 1:0:0 -t 1:ef00 -c 1:boot /dev/vde")
    machine.succeed("partx -u /dev/vde")
    machine.succeed("udevadm settle")
    machine.succeed("mkfs.vfat -F 32 -n TESTESP /dev/vde1")
    machine.succeed("mkdir -p /boot && mount -t vfat /dev/vde1 /boot")
    machine.succeed("mkdir -p /boot/EFI/Microsoft/Boot")
    machine.succeed("printf 'windows-bootmgr\\n' > /boot/EFI/Microsoft/Boot/bootmgfw.efi")
    machine.succeed("printf 'windows-bcd\\n' > /boot/EFI/Microsoft/Boot/BCD")
    shared_before = machine.succeed(
        "find /boot/EFI/Microsoft -type f -print0 | sort -z | xargs -0 sha256sum"
    )
    esp_uuid_before = machine.succeed("blkid -s UUID -o value /dev/vde1").strip()

    # Separate Windows-like disk: ESP + MSR + Windows data partition.
    machine.succeed("sgdisk --zap-all /dev/vdd")
    machine.succeed("sgdisk -n 1:0:+32M -t 1:ef00 -c 1:WINESP /dev/vdd")
    machine.succeed("sgdisk -n 2:0:+16M -t 2:0c01 -c 2:MSR /dev/vdd")
    machine.succeed("sgdisk -n 3:0:0 -t 3:0700 -c 3:Windows /dev/vdd")
    machine.succeed("partx -u /dev/vdd")
    machine.succeed("udevadm settle")
    machine.succeed("mkfs.vfat -F 32 -n WINESP /dev/vdd1")
    machine.succeed("mkdir -p /mnt/winesp && mount -t vfat /dev/vdd1 /mnt/winesp")
    machine.succeed("mkdir -p /mnt/winesp/EFI/Microsoft/Boot")
    machine.succeed("printf 'other-windows-bootmgr\\n' > /mnt/winesp/EFI/Microsoft/Boot/bootmgfw.efi")
    machine.succeed("umount /mnt/winesp")
    machine.succeed("sgdisk --backup=/tmp/windows.gpt.before /dev/vdd")
    windows_raw_before = checksum("/dev/vdd")
    windows_esp_before = checksum("/dev/vdd1")

    # Fake Windows NVRAM entry.
    machine.succeed(
        "efibootmgr --create --label 'Windows Boot Manager' "
        "--disk /dev/vdd --part 1 --loader '\\\\EFI\\\\Microsoft\\\\Boot\\\\bootmgfw.efi'"
    )
    efibootmgr_before = machine.succeed("efibootmgr -v")

    root_gpt_before = machine.succeed("sgdisk --backup=/tmp/root.gpt.before /dev/vdc")
    storage_before = checksum("/root/angst/hosts/personal/generic/storage.nix")

    # Dry run must not create subvolumes or write storage/boot entries.
    run("cd /root/angst && ${provision} --dry-run > /tmp/provision.dry.out 2>&1")
    machine.succeed("cmp /tmp/root.gpt.before /tmp/root.gpt.before")
    machine.succeed("test ! -e /run/angst-btrfs/@root")
    machine.succeed(f"test \"$(sha256sum /root/angst/hosts/personal/generic/storage.nix | cut -d' ' -f1)\" = \"{storage_before}\"")

    # Real migration.
    status, output = machine.execute(
        "cd /root/angst && printf 'MIGRATE\\n' | ${provision} > /tmp/provision.out 2>&1"
    )
    print(output)
    print(machine.succeed("cat /root/angst/hosts/personal/generic/storage.nix"))
    assert status == 0, machine.succeed("cat /tmp/provision.out")

    machine.succeed("sgdisk --backup=/tmp/root.gpt.after /dev/vdc")
    machine.succeed("cmp /tmp/root.gpt.before /tmp/root.gpt.after")
    machine.succeed("sgdisk --backup=/tmp/windows.gpt.after /dev/vdd")
    machine.succeed("cmp /tmp/windows.gpt.before /tmp/windows.gpt.after")
    machine.succeed(f"test \"$(sha256sum /dev/vdd | cut -d' ' -f1)\" = \"{windows_raw_before}\"")
    machine.succeed(f"test \"$(blkid -s UUID -o value /dev/vde1)\" = \"{esp_uuid_before}\"")
    machine.succeed("printf '%s' " + shlex.quote(shared_before) + " > /tmp/shared.before")
    machine.succeed("find /boot/EFI/Microsoft -type f -print0 | sort -z | xargs -0 sha256sum > /tmp/shared.after")
    machine.succeed("cmp /tmp/shared.before /tmp/shared.after")
    machine.succeed("efibootmgr -v > /tmp/efi.after")
    machine.succeed("grep -F 'Windows Boot Manager' /tmp/efi.after")

    machine.succeed("btrfs subvolume list / | grep -E 'path @(root|home|nix|state)$' | wc -l | grep -qx 4")
    machine.succeed("grep -F 'subvol=@root' /root/angst/hosts/personal/generic/storage.nix")
    machine.succeed("grep -F 'subvol=@home' /root/angst/hosts/personal/generic/storage.nix")
    machine.succeed("grep -F 'subvol=@nix' /root/angst/hosts/personal/generic/storage.nix")
    machine.fail("grep -F '/state' /root/angst/hosts/personal/generic/storage.nix")

    # Generic boot entry must exist and point at @root; old entry remains.
    machine.succeed("bootctl list > /tmp/bootctl.after")
    machine.succeed("grep -F 'generic' /tmp/bootctl.after || grep -F 'NixOS' /tmp/bootctl.after")

    # Reboot into the migrated root with kexec (the test framework direct-boots).
    machine.execute("kexec -l ${genericKernel} --initrd=${genericInitrd} --append='init=${genericToplevel}/init root=fstab'")
    try:
        machine.execute("kexec -e")
    except Exception as error:
        print(f"kexec disconnected the test shell: {error}")
    time.sleep(10)
    machine.connect()
    machine.wait_for_unit("multi-user.target", timeout=180)

    machine.succeed("test \"$(cat /etc/hostname)\" = generic")
    machine.succeed("findmnt -no FSTYPE / | grep -qx btrfs")
    machine.succeed("findmnt -no FSROOT / | grep -F '@root'")
    machine.succeed("findmnt -no FSROOT /home | grep -F '@home'")
    machine.succeed("findmnt -no FSROOT /nix | grep -F '@nix'")
    machine.fail("findmnt /state")
    machine.succeed("id user")
    machine.succeed("runuser -u user -- i3 -C -c /home/user/.config/i3/config")
    machine.succeed("runuser -u user -- i3status-rs --version")
    machine.succeed("runuser -u user -- ghostty --version")
    machine.succeed("runuser -u user -- yazi --version")
    machine.succeed("runuser -u user -- firefox --version")
    machine.succeed("runuser -u user -- opencode --version")
    machine.succeed("systemctl is-enabled ly.service")
    machine.succeed("systemctl is-active home-manager-user.service")

    # Windows/ESP preservation after boot.
    machine.succeed("sgdisk --backup=/tmp/windows.gpt.reboot /dev/vdd")
    machine.succeed("cmp /tmp/windows.gpt.before /tmp/windows.gpt.reboot")
    machine.succeed(f"test \"$(sha256sum /dev/vdd | cut -d' ' -f1)\" = \"{windows_raw_before}\"")
    machine.succeed("find /boot/EFI/Microsoft -type f -print0 | sort -z | xargs -0 sha256sum > /tmp/shared.reboot")
    machine.succeed("cmp /tmp/shared.before /tmp/shared.reboot")
    machine.succeed("efibootmgr -v > /tmp/efi.reboot")
    machine.succeed("grep -F 'Windows Boot Manager' /tmp/efi.reboot")

    # Generic switch must preserve the same invariants.
    run("cd /root/angst && printf 'generic\\n' | ${switch} > /tmp/switch.out 2>&1")
    machine.succeed("sgdisk --backup=/tmp/windows.gpt.switch /dev/vdd")
    machine.succeed("cmp /tmp/windows.gpt.before /tmp/windows.gpt.switch")
    machine.succeed(f"test \"$(sha256sum /dev/vdd | cut -d' ' -f1)\" = \"{windows_raw_before}\"")
    machine.succeed("find /boot/EFI/Microsoft -type f -print0 | sort -z | xargs -0 sha256sum > /tmp/shared.switch")
    machine.succeed("cmp /tmp/shared.before /tmp/shared.switch")
    machine.succeed("efibootmgr -v > /tmp/efi.switch")
    machine.succeed("grep -F 'Windows Boot Manager' /tmp/efi.switch")
  '';
}
