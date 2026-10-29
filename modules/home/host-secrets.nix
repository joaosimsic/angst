{
  lib,
  pkgs,
  flakeSelf,
  userConfig,
  hostname,
  hostHostSecrets ? [ ],
  ...
}:

let
  parse =
    raw:
    let
      parts = lib.splitString "/" raw;
    in
    {
      scope = builtins.elemAt parts 0;
      name = builtins.elemAt parts 1;
    };

  entries = map parse hostHostSecrets;

  keyFile =
    entry:
    "${userConfig.homeDirectory}/.config/age/${
      if entry.scope == "work" then "work-keys.txt" else "keys.txt"
    }";

  decrypt =
    entry:
    let
      src = "${flakeSelf}/secrets/${entry.name}/${hostname}.age";
      dest = "${userConfig.homeDirectory}/.secrets/${entry.name}";
    in
    ''
      if [ ! -f ${lib.escapeShellArg src} ]; then
        echo "warn: host secret ${entry.name} is not present at ${src}" >&2
      elif [ ! -f ${lib.escapeShellArg (keyFile entry)} ]; then
        echo "warn: no ${entry.scope} age key for host secret ${entry.name}" >&2
      elif { rm -f ${lib.escapeShellArg dest}; ${pkgs.age}/bin/age --decrypt \
        --identity ${lib.escapeShellArg (keyFile entry)} \
        --output ${lib.escapeShellArg dest} \
        ${lib.escapeShellArg src}; }; then
        chmod 0600 ${lib.escapeShellArg dest}
      else
        rm -f ${lib.escapeShellArg dest}
        echo "warn: could not decrypt host secret ${entry.name}" >&2
      fi
    '';
in
lib.mkIf (hostHostSecrets != [ ]) {
  home.activation.angstHostSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 0700 "$HOME/.secrets"
    ${lib.concatMapStrings decrypt entries}
  '';
}
