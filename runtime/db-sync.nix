{
  mkScript,
  pkgs,
  lib,
  goAngst,
}:
{
  db,
  flakeSelf,
}:
mkScript {
  name = "angst-db-sync";
  runtimeInputs = with pkgs; [
    age
  ];
  text = ''
    export ANGST_DB_STORE="$HOME/.secrets/db"
    export ANGST_DB_REPO="${flakeSelf}/secrets/db"
    export ANGST_DB_ONLY='${lib.concatStringsSep " " db}'
    exec ${goAngst}/bin/angst db "$@"
  '';
}
