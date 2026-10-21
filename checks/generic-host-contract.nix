{
  self,
  lib,
  pkgs,
}:

let
  cfg = self.nixosConfigurations.generic.config;
  hm = lib.attrByPath [ "home-manager" "users" "user" ] { } cfg;

  get = path: default: lib.attrByPath path default cfg;
  getHm = path: default: lib.attrByPath path default hm;

  checks = [
    {
      name = "hostname";
      ok = cfg.networking.hostName == "generic";
    }
    {
      name = "user";
      ok = (get [ "users" "users" "user" "isNormalUser" ] false) == true;
    }
    {
      name = "generic guard";
      ok = (get [ "angst" "genericHost" "enable" ] false) == true;
    }
    {
      name = "generic acknowledgement";
      ok = (get [ "angst" "genericHost" "acknowledgeDiskChanges" ] false) == true;
    }
    {
      name = "no impermanence";
      ok = (get [ "environment" "persistence" ] { }) == { };
    }
    {
      name = "no /state mount";
      ok = (get [ "fileSystems" "/state" ] null) == null;
    }
    {
      name = "no tmpfs home";
      ok = (get [ "fileSystems" "/home/user" ] null) == null;
    }
    {
      name = "root is not tmpfs";
      ok = (get [ "fileSystems" "/" "fsType" ] "") != "tmpfs";
    }
    {
      name = "root subvolume";
      ok = lib.elem "subvol=@root" (get [ "fileSystems" "/" "options" ] [ ]);
    }
    {
      name = "home subvolume";
      ok = lib.elem "subvol=@home" (get [ "fileSystems" "/home" "options" ] [ ]);
    }
    {
      name = "nix subvolume";
      ok = lib.elem "subvol=@nix" (get [ "fileSystems" "/nix" "options" ] [ ]);
    }
    {
      name = "boot is vfat";
      ok = (get [ "fileSystems" "/boot" "fsType" ] "") == "vfat";
    }
    {
      name = "btrfs initrd module";
      ok = lib.elem "btrfs" (get [ "boot" "initrd" "availableKernelModules" ] [ ]);
    }
    {
      name = "opencode domain";
      ok = (getHm [ "domains" "agents" "opencode" "enable" ] false) == true;
    }
    {
      name = "rea domain";
      ok = (getHm [ "domains" "agents" "rea" "enable" ] false) == true;
    }
    {
      name = "firefox domain";
      ok = (get [ "domains" "browser" "firefox" "enable" ] false) == true;
    }
    {
      name = "display gpu domain";
      ok = (getHm [ "domains" "display" "gpu" "enable" ] false) == true;
    }
    {
      name = "graphical domain";
      ok = (get [ "domains" "kernel" "graphical" "enable" ] false) == true;
    }
    {
      name = "x11 domain";
      ok = (get [ "domains" "display" "x11" "enable" ] false) == true;
    }
    {
      name = "ly domain";
      ok = (get [ "domains" "display" "ly" "enable" ] false) == true;
    }
    {
      name = "i3 domain";
      ok = (get [ "domains" "wm" "i3" "enable" ] false) == true;
    }
    {
      name = "i3status domain";
      ok = (getHm [ "domains" "bar" "i3status-rust" "enable" ] false) == true;
    }
    {
      name = "ghostty domain";
      ok = (getHm [ "domains" "terminal" "ghostty" "enable" ] false) == true;
    }
    {
      name = "yazi domain";
      ok = (getHm [ "domains" "files" "yazi" "enable" ] false) == true;
    }
    {
      name = "xserver";
      ok = (get [ "services" "xserver" "enable" ] false) == true;
    }
    {
      name = "i3 window manager";
      ok = (get [ "services" "xserver" "windowManager" "i3" "enable" ] false) == true;
    }
    {
      name = "ly display manager";
      ok = (get [ "services" "displayManager" "ly" "enable" ] false) == true;
    }
    {
      name = "firefox program";
      ok = (get [ "programs" "firefox" "enable" ] false) == true;
    }
    {
      name = "graphics";
      ok = (get [ "hardware" "graphics" "enable" ] false) == true;
    }
    {
      name = "zram";
      ok = (get [ "zramSwap" "enable" ] false) == true;
    }
    {
      name = "home-manager firefox";
      ok = (getHm [ "programs" "firefox" "enable" ] false) == true;
    }
    {
      name = "opencode config";
      ok =
        lib.hasInfix "OPENCODE_GO_API_KEY"
          (getHm [ "home" "file" ".config/opencode/opencode.jsonc" "text" ] "");
    }
    {
      name = "i3 status command";
      ok =
        lib.hasInfix "i3status-rs"
          (getHm [ "home" "file" ".config/i3/config" "text" ] "");
    }
    {
      name = "i3 ghostty binding";
      ok =
        lib.hasInfix "ghostty"
          (getHm [ "home" "file" ".config/i3/config" "text" ] "");
    }
    {
      name = "i3 workspace group";
      ok =
        lib.hasInfix "i3-workspace-group"
          (getHm [ "home" "file" ".config/i3/config" "text" ] "");
    }
  ];

  failed = builtins.filter (c: !c.ok) checks;
in
if failed != [ ] then
  throw "generic-host-contract: failed checks: ${lib.concatStringsSep ", " (map (c: c.name) failed)}"
else
  pkgs.runCommand "generic-host-contract" { } ''
    mkdir -p "$out"
    printf '%s\n' "generic host contract passed" >"$out/README"
  ''
