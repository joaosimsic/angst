{
  lib,
  pkgs,
}:

let
  unwrapped = pkgs.buildGoModule {
    pname = "i3-workspace-group";
    version = "0.1.0";
    src = ./workspace-group;
    subPackages = [ "cmd/i3-workspace-group" ];
    vendorHash = "sha256-+xGOC1RbSnPJ0dYlhVz1L0vo90JxEAfptfpUaYJ3t+E=";
    checkPhase = ''
      runHook preCheck
      go test ./...
      runHook postCheck
    '';
  };
in
pkgs.runCommand "i3-workspace-group" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/bin
  makeWrapper ${unwrapped}/bin/i3-workspace-group $out/bin/i3-workspace-group \
    --prefix PATH : ${lib.makeBinPath [ pkgs.i3 ]}
''
