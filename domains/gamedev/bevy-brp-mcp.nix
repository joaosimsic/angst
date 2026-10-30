{
  lib,
  fetchCrate,
  openssl,
  pkg-config,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "bevy_brp_mcp";
  version = "0.22.10";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-pRZNy59fFCX1pD59wCS1eTdUP4Vgw1aF54RziJi/n8k=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  doCheck = false;

  meta = {
    description = "MCP server for Bevy Remote Protocol (BRP) integration";
    homepage = "https://github.com/natepiano/bevy_brp";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "bevy_brp_mcp";
  };
}
