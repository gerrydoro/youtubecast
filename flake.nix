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
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ bun2nix.overlays.default ];
      };
    in {
      packages = {
        default = self.packages.${system}.youtubecast;
        youtubecast = import ./modules/youtubecast.nix {
          inherit pkgs;
        };
      };

      apps = {
        default = self.packages.${system}.youtubecast;
        youtubecast = self.packages.${system}.youtubecast;
      };

      devShells.default = import ./devshell.nix {
        inherit pkgs;
      };
    });
}
