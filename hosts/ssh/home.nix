{ lib, ... }: {
  imports = [ ../../common/home.nix ];

  home.file.".profile" = {
    text = ''
      if [ -x "$(command -v nu)" ]; then
        exec nu -l
      fi
    '';
    force = true;
  };
}
