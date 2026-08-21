{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.cursor-cli.enable {
    programs.bash.bashrcExtra = lib.mkAfter ''
      if [ -f "$HOME/.secrets/cursor-api-key" ]; then
        export CURSOR_API_KEY="$(cat "$HOME/.secrets/cursor-api-key")"
      fi
    '';

    programs.nushell.extraConfig = lib.mkAfter ''
      if ("$HOME/.secrets/cursor-api-key" | path exists) {
        $env.CURSOR_API_KEY = (open "$HOME/.secrets/cursor-api-key" | str trim)
      }
    '';
  };
}
