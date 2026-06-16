{
  system = "x86_64-linux";

  theme = "kanagawa";

  user = {
    username = "joao";
    homeDirectory = "/home/joao";

    ssh = {
      identityFile = "~/.ssh/id_ed25519";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSgA6EHXcywZBbJuJnULFMz4Did28tsR1Rtg7dHCBAB jpsimsic@hotmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINn72OmW1reZqSV3UIRiYEOr6yFLYfwl/XmrscGFQwKz joao.simsic@4x4brasil.com.br"
      ];
    };

    git = {
      sshHosts = {
        "github.com" = {
          user = "git";
          identityFile = "~/.ssh/id_ed25519";
          strictHostKeyChecking = "accept-new";
        };
      };
    };
  };

  monitors = {
    primary = {
      name = "DP-1";
      resolution = "1920x1080";
      refreshRate = 144;
      position = "0x0";
    };

    secondary = {
      name = "HDMI-A-2";
      resolution = "1920x1080";
      refreshRate = 60;
      position = "1920x0";
    };
  };
}
