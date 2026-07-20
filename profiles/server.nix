{ mkDomainEnable, mkCap }:
{
  hm = [ ];
  nixos = [
    (mkCap "ssh")
  ];
}
