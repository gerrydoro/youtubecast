{
  description = "Generate podcast feeds from YouTube channels and playlists";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, bun2nix, flake-utils }:
    let
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ bun2nix.overlays.default ];
      };
    in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = pkgsFor system;
    in {
      packages = {
        default = self.packages.${system}.youtubecast;
        youtubecast = import ./modules/youtubecast.nix {
          inherit pkgs;
        };
      };

      devShells.default = import ./devshell.nix {
        inherit pkgs;
      };
    }) // {
      nixosModules.default = import ./modules/default.nix;
    };
}
