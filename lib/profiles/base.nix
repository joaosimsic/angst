{ mkDomainEnable }:
{
  hm = [
    (mkDomainEnable "shell.nushell")
    (mkDomainEnable "shell.starship")
    (mkDomainEnable "terminal.zellij")
    (mkDomainEnable "editor.nvim")
    (mkDomainEnable "files.yazi")
    (mkDomainEnable "git.lazygit")
  ];
  nixos = [
    ({ ... }: {
      capabilities.network.enable = true;
      capabilities.git.enable = true;
      capabilities.search.enable = true;
      capabilities.monitoring.enable = true;
      capabilities.container.enable = true;
    })
    ../../capabilities/network.nix
    ../../capabilities/git.nix
    ../../capabilities/search.nix
    ../../capabilities/monitoring.nix
    ../../capabilities/container.nix
  ];
}
