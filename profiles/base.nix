{ mkDomainEnable, mkCap }:
{
  hm = [
    (mkDomainEnable "shell.nushell")
    (mkDomainEnable "shell.carapace")
    (mkDomainEnable "shell.starship")
    (mkDomainEnable "terminal.zellij")
    (mkDomainEnable "editor.nvim")
    (mkDomainEnable "files.yazi")
    (mkDomainEnable "git.lazygit")
    (mkDomainEnable "nix.nh")
    (mkDomainEnable "security.age")
    (mkDomainEnable "security.sops")
  ];
  nixos = [
    (mkCap "network")
    (mkCap "git")
    (mkCap "search")
    (mkCap "monitoring")
    (mkCap "container")
  ];
}
