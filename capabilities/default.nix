_:

let
  entries = builtins.readDir ./.;
  names = builtins.attrNames entries;

  isNixFile =
    name:
    let
      len = builtins.stringLength name;
    in
    len > 4
    && builtins.substring (len - 4) 4 name == ".nix"
    && name != "default.nix"
    && entries.${name} == "regular";

  toAttr = name: {
    name = builtins.substring 0 (builtins.stringLength name - 4) name;
    value = ./${name};
  };
in
builtins.listToAttrs (map toAttr (builtins.filter isNixFile names))
