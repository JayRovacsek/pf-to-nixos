{
  description =
    "pf-to-nixos, A minimally viable route to declarative routing infrastructure from pfSense configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat = {
      flake = false;
      url = "github:edolstra/flake-compat";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs, ... }:
    let
      flake-utils-outputs = flake-utils.lib.eachDefaultSystem (system:
        let pkgs = import self.inputs.nixpkgs { inherit system; };
        in { packages = import ./packages { inherit pkgs self; }; });

      standard-outputs = { lib = import ./lib { inherit self; }; };

    in flake-utils-outputs // standard-outputs;
}
