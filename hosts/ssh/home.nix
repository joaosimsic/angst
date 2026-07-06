{ lib, ... }: {
  imports = [ ../../common/home.nix ];

  nixpkgs.overlays = [
    (self: super: {
      opencode = super.opencode.overrideAttrs (old: {
        preBuild = (old.preBuild or "") + ''
          export GOAMD64=v1
        '';
      });
    })
  ];

  home.file.".profile" = {
    text = ''
      if [ -x "$(command -v nu)" ]; then
        exec nu -l
      fi
    '';
    force = true;
  };
}
