{ mkDomainEnable }:
{
  hm = [ ];
  nixos = [
    ({ ... }: {
      capabilities.ssh.enable = true;
    })
    ../capabilities/ssh.nix
  ];
}
