{
  lib,
  pkgs,
}:

let
  unwrapped = pkgs.buildGoModule {
    pname = "i3-tools";
    version = "0.1.0";
    src = ./workspace-group;
    subPackages = [
      "cmd/i3-workspace-group"
      "cmd/i3-mouse-hold"
    ];
    vendorHash = "sha256-eG2VwCgW9r41w1DbU9TEeXnQH5drC28rXdfEKCqAQis=";
    checkPhase = ''
      runHook preCheck
      go test ./...
      runHook postCheck
    '';
  };
in
pkgs.runCommand "i3-tools" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/bin
  makeWrapper ${unwrapped}/bin/i3-workspace-group $out/bin/i3-workspace-group \
    --prefix PATH : ${lib.makeBinPath [ pkgs.i3 ]}
  cp ${unwrapped}/bin/i3-mouse-hold $out/bin/i3-mouse-hold
''
