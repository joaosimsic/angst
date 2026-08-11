{ lib }:

hostsDir:

let
  top = builtins.readDir hostsDir;
  hasNix = d: (builtins.readDir d) ? "default.nix";

  classify =
    name:
    let
      t = top.${name};
    in
    if t != "directory" then
      null
    else if hasNix (hostsDir + "/${name}") then
      {
        hostname = name;
        domain = null;
        dir = name;
      }
    else
      let
        sub = builtins.readDir (hostsDir + "/${name}");
        hosts = builtins.filter (n: sub.${n} == "directory" && hasNix (hostsDir + "/${name}/${n}")) (
          builtins.attrNames sub
        );
      in
      map (h: {
        hostname = h;
        domain = name;
        dir = "${name}/${h}";
      }) hosts;
in
lib.flatten (lib.remove null (map classify (builtins.attrNames top)))
