{ mkDomainEnable, mkCap }:
{
  hm = [
    (mkDomainEnable "agents.opencode")
    (mkDomainEnable "agents.cursor-cli")
    (mkDomainEnable "sql-client.sqlit")
    (mkDomainEnable "http-client.posting")
  ];
  nixos = [ ];
}
