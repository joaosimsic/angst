{
  pkgs,
  ...
}:

let
  edid = pkgs.runCommand "edid-nixos" { } ''
    mkdir -p "$out/lib/firmware/edid"
    printf '%s' "AP///////wAQrG6hQjkwMSgeAQSlNR54O3K1p1VSoCcQUFSlSwBxT4GAqcDRwAEBAQEBAQEBAjqAGHE4LUBYLEUADyghAAAeAAAA/wAxVjBXTDIzCiAgICAgAAAA/ABERUxMIFMyNDIxSEdGAAAA/QAwkKqqIgEKICAgICAgAQgCAyzxUZAFBAMCBxYBFB8SEwYRFT9AIwkHB4MBAABtGgAAAgEwkAAAAAAAAIZvgKBwOEBAMCA1AA8oIQAAGtiDgKBwODBAMCA1AA8oIQAAGgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACA==" | ${pkgs.coreutils}/bin/base64 -d > "$out/lib/firmware/edid/dp1.bin"
    printf '%s' "AP///////wAEci0D/JhgARAeAQOAMBt4KoTVolpSoiYNUFSzDADRwLMAlQCBgIEAgcBxTwEBAjqAGHE4LUBYLEUA3QwRAAAeAAAA/QA3TB5TEQAKICAgICAgAAAA/wBMWExBQTAxNDQyNzEKAAAA/ABBY2VyIFYyMjZIUUwKAaMCAx7xZQMMABAAS5ACAwQREhMFFB8BIwkHAYMBAAACOoAYcTgtQFgsRQDdDBEAAB6MCtCKIOAtEBA+lgDdDBEAABgBHQByUdAeIG4oVQDdDBEAAB6MCtCQIEAxIAxAVQDdDBEAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIw==" | ${pkgs.coreutils}/bin/base64 -d > "$out/lib/firmware/edid/hdmi2.bin"
  '';
in
{
  hardware.display.edid.packages = [ edid ];

  hardware.display.outputs = {
    "DP-1" = {
      edid = "dp1.bin";
      mode = "e";
    };
    "HDMI-A-2" = {
      edid = "hdmi2.bin";
      mode = "e";
    };
  };

  boot.initrd.extraFirmwarePaths = [
    "edid/dp1.bin"
    "edid/hdmi2.bin"
  ];
}
