{ mkCap, ... }:
{
  hm = [ ];
  nixos = [
    (mkCap "ssh")
  ];
}
