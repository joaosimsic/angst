{ pkgs }: {
  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = with pkgs; [ coreutils findutils git nix watchexec jq ];
    text = builtins.readFile ../scripts/angst.sh;
  };
}
