{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, ... }: {
    lib.logger = import ./infra/logger/default.nix;
    lib.tests.secret-ref = import ./infra/contracts/secret-ref.test.nix;
  };
}
