{ mkDomainEnable, mkCap }:
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
    (mkCap "network")
    (mkCap "git")
    (mkCap "search")
    (mkCap "monitoring")
    (mkCap "container")
  ];
}
