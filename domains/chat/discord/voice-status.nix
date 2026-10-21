{ pkgs }:

pkgs.buildGoModule {
  pname = "angst-discord-voice";
  version = "0.1.0";
  src = ./voice-status;
  vendorHash = null;
  subPackages = [ "." ];
  postInstall = ''
    mv $out/bin/discordvoice $out/bin/angst-discord-voice
  '';
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';
}
