{
  config,
  lib,
  pkgs,
  ...
}:

let
  nu = "${pkgs.nushell}/bin/nu";
  dir = "${config.xdg.configHome}/nushell";
  files = [
    "env.nu"
    "config.nu"
    "colors.nu"
    "ssh-agent.nu"
  ];
  filesList = lib.concatMapStringsSep " " (f: "\"${f}\"") files;
  q = "'";
  code = "for f in [${filesList}] { let p = (\"${dir}\" | path join ${"$"}f); if (${"$"}p | path exists) and ((nu-check ${"$"}p) == false) { print (\"invalid nushell config: \" + ${"$"}p); exit 1 } }";
in
{
  cmd = "${nu} --no-config-file -c ${q}${code}${q}";
  fatal = true;
}
