{
  config,
  lib,
  host,
  ...
}:

let
  cfg = config.domains.git.code;
  git = host.git or { };
  defaultScope = git.default or "personal";
  personal = git.personal or null;
  work = git.work or null;
  primary = if defaultScope == "work" then work else personal;
  useWorkInclude = work != null && defaultScope != "work";
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && primary != null) {
      programs.git = {
        enable = true;
        settings = [
          {
            user = {
              name = primary.name;
              email = primary.email;
            };
          }
        ]
        ++ lib.optional useWorkInclude {
          includeIf."hasconfig:remote.*.url:git@gitlab.ezvoice.com.br:*/**".path = "~/.config/git/work.inc";
          includeIf."hasconfig:remote.*.url:https://gitlab.ezvoice.com.br/**".path = "~/.config/git/work.inc";
        };
      };
    })
    (lib.mkIf (cfg.enable && primary != null && useWorkInclude) {
      xdg.configFile."git/work.inc".text = ''
        [user]
          name = ${work.name}
          email = ${work.email}
      '';
    })
  ];
}
