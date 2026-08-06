{ mkDomainEnable, ... }:
{
  hm = [
    (mkDomainEnable "agents.opencode")
    (mkDomainEnable "agents.cursor-cli")
    (mkDomainEnable "sql-client.sqlit")
    (mkDomainEnable "sql-client.rainfrog")
    (mkDomainEnable "http-client.posting")
  ];
  nixos = [ ];
}
