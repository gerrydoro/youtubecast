{ pkgs }:

let
  commonDeps = with pkgs; [
    bun
    nodejs
    ffmpeg
    yt-dlp
    python3
  ];

  backendDeps = with pkgs; [
    openssl
    zlib
    zstd
    libiconv
  ];

  rootDeps = pkgs.bun2nix.fetchBunDeps {
    bunNix = ./bun-root.nix;
  };

  uiDeps = pkgs.bun2nix.fetchBunDeps {
    bunNix = ./ui-bun.nix;
  };

  frontend = pkgs.stdenvNoCC.mkDerivation {
    name = "youtubecast-frontend";

    src = ../ui;

    nativeBuildInputs = [ pkgs.bun2nix.hook ];
    bunDeps = uiDeps;
    packageJson = ../ui/package.json;

    dontUseBunInstall = true;

    buildPhase = ''
      bun run build
    '';

    installPhase = ''
      mkdir -p $out/static
      cp -r ../static/* $out/static/ 2>/dev/null || true
    '';
  };

in pkgs.stdenvNoCC.mkDerivation {
  name = "youtubecast";

  src = pkgs.lib.cleanSourceWith {
    filter = _name: type:
      type == "directory" ||
      baseNameOf _name == "package.json" ||
      baseNameOf _name == "bun.lock" ||
      baseNameOf _name == "tsconfig.json" ||
      baseNameOf _name == "eslint.config.mjs" ||
      baseNameOf _name == "start.sh" ||
      baseNameOf _name == "nginx.conf" ||
      (type == "directory" && baseNameOf _name == "src") ||
      (type == "file" && pkgs.lib.hasSuffix "/bun.lock" _name) ||
      baseNameOf _name == "bun-root.nix" ||
      baseNameOf _name == "ui-bun.nix";
    src = ../.;
  };

  nativeBuildInputs = commonDeps ++ [ pkgs.bun2nix.hook ];
  buildInputs = backendDeps;

  bunDeps = rootDeps;

  dontUseBunBuild = true;

  LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:${pkgs.zstd.out}/lib";

  installPhase = ''
    mkdir -p $out/bin $out/app

    # Copy backend source and node_modules
    cp -r src node_modules $out/app/

    # Copy built frontend static files from frontend derivation
    cp -r ${frontend}/static $out/app/static

    # Copy nginx config (port will be replaced by NixOS module)
    cp nginx.conf $out/app/nginx.conf

    # Copy startup script
    cp start.sh $out/bin/youtubecast-start
    chmod +x $out/bin/youtubecast-start

    # Copy nginx.conf to app dir for reference
    cp nginx.conf $out/app/nginx.example
  '';
}
