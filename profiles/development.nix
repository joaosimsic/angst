{ mkDomainEnable }:
{
  hm = [
    (mkDomainEnable "llm.opencode")
    (mkDomainEnable "llm.cursor-cli")
    (mkDomainEnable "sql-client.sqlit")
    (mkDomainEnable "http-client.posting")
  ];
  nixos = [ ];
}
