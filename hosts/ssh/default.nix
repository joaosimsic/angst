{
  system = "x86_64-linux";

  theme = "monochrome";

  user = {
    username = "joao";
    homeDirectory = "/home/joao";

    ssh = {
      identityFile = "~/.ssh/id_ed25519";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOsmeoPJnZEE7AnCpSik4QsgjLr3cRy8W3Nmi0Ee5OF jpsimsic@hotmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEeJVdPiDa6ato/McVlwbjwifFmKoqF0/sPVCLSo82kQ joao.simsic@4x4brasil.com.br"
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
}
