{
  enable = [
    "remote.ssh"
    "display.ly"
  ];
  modules = [
    ../modules/vm/runtime.nix
    ../modules/vm/vm-variant.nix
    ../modules/vm/vm-profile.nix
    ../modules/vm/host-mount.nix
    ({ lib, pkgs, ... }: {
      config = {
        angst.isQemuVm = lib.mkForce true;
        domains.display.lightdm.enable = lib.mkForce false;
        services.xserver.windowManager.i3.enable = lib.mkForce false;
        environment.systemPackages = [ pkgs.i3 ];
        services.displayManager.autoLogin = {
          enable = lib.mkForce true;
          user = lib.mkForce "joao";
        };
      };
    })
  ];
}
