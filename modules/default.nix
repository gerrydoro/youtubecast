{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.services.youtubecast;
  bun2nix = config.specialArgs.bun2nix;
  pkgsBun = import nixpkgs {
    inherit (pkgs) system;
    overlays = [ bun2nix.overlays.default ];
  };
in {
  options.services.youtubecast = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the YouTubeCast service.";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for nginx to listen on (external).";
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          youtubeApiKey = mkOption {
            type = types.str;
            default = "";
            description = "YouTube Data API v3 key.";
          };
          downloadVideos = mkOption {
            type = types.bool;
            default = false;
            description = "Enable video downloads.";
          };
          maximumCompatibility = mkOption {
            type = types.bool;
            default = false;
            description = "Download videos as MP4 instead of HLS.";
          };
          highestQuality = mkOption {
            type = types.bool;
            default = false;
            description = "Use 1080p+ video quality.";
          };
          cacheTimeToLive = mkOption {
            type = types.int;
            default = 1200;
            description = "Cache TTL in seconds (default: 1200).";
          };
          minimumVideoDuration = mkOption {
            type = types.int;
            default = 180;
            description = "Minimum video duration in seconds (default: 180).";
          };
        };
      };
      default = {
        youtubeApiKey = "";
        downloadVideos = false;
        maximumCompatibility = false;
        highestQuality = false;
        cacheTimeToLive = 1200;
        minimumVideoDuration = 180;
      };
      description = "YouTubeCast settings (equivalent to settings.json).";
    };

    youtubeApiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the YouTube API key.
        Takes precedence over `settings.youtubeApiKey`.
        Useful for SOPS-nix integration.
      '';
    };

    cookiesFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a cookies.txt file for authenticated YouTube content.";
    };

    contentDir = mkOption {
      type = types.path;
      default = "/var/lib/youtubecast";
      description = "Directory for storing downloaded videos.";
    };

    user = mkOption {
      type = types.str;
      default = "youtubecast";
      description = "Service user name.";
    };

    group = mkOption {
      type = types.str;
      default = "youtubecast";
      description = "Service group name.";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Network interface for nginx to bind to.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to an environment file for service variables.";
    };
  };

  config = mkIf cfg.enable (
    let
      pkg = import ../modules/youtubecast.nix { inherit pkgsBun; };
    in {
      # Create service user and group
      users.groups.${cfg.group} = {};
      users.users.${cfg.user} = {
        extraGroups = [ cfg.group ];
        isSystemUser = true;
        group = cfg.group;
      };

      # Generate settings.json
      environment.etc."youtubecast/settings.json" =
        let
          key = if cfg.youtubeApiKeyFile != null
            then pkgs.lib.readFile cfg.youtubeApiKeyFile
            else cfg.settings.youtubeApiKey;
          dl = if cfg.settings.downloadVideos then "true" else "false";
          mc = if cfg.settings.maximumCompatibility then "true" else "false";
          hq = if cfg.settings.highestQuality then "true" else "false";
        in
        pkgs.runCommand "settings.json" { } ''
          cat > $out <<EOF
        {
          "youtubeApiKey": "${key}",
          "downloadVideos": ${dl},
          "maximumCompatibility": ${mc},
          "highestQuality": ${hq},
          "cacheTimeToLive": "${toString cfg.settings.cacheTimeToLive}",
          "minimumVideoDuration": "${toString cfg.settings.minimumVideoDuration}"
        }
        EOF
        '';

      # Copy cookies file if provided
      environment.etc."youtubecast/cookies.txt" = mkIf (cfg.cookiesFile != null) {
        source = cfg.cookiesFile;
      };

      # Generate nginx config
      environment.etc."youtubecast/nginx.conf" =
        pkgs.runCommand "nginx.conf" { } ''
          sed 's/${toString cfg.port}/${toString cfg.port}/g' ${./../nginx.conf} > $out
        '';

      # Create content directory
      systemd.tmpfiles.rules = [
        "d ${cfg.contentDir} 0750 ${cfg.user} ${cfg.group} -"
      ];

      # Systemd service
      systemd.services.youtubecast = {
        description = "YouTubeCast - Generate podcast feeds from YouTube";
        wantedBy = [ "multi-user.target" ];
        wants = [ "nginx.service" ];
        after = [ "nginx.service" ];

        environment = {
          APP_DIR = "${pkg}/app";
          NGINX_CONF = "/etc/youtubecast/nginx.conf";
          CONTENT_DIR = cfg.contentDir;
          YOUTUBECAST_PORT = toString cfg.port;
        } // optionalAttrs (cfg.environmentFile != null) {
          ENVIRONMENT_FILE = cfg.environmentFile;
        };

        preStart = ''
          mkdir -p $CONTENT_DIR

          # Copy settings and cookies to runtime directory
          cp /etc/youtubecast/settings.json $CONTENT_DIR/
          if [ -f /etc/youtubecast/cookies.txt ]; then
            cp /etc/youtubecast/cookies.txt $CONTENT_DIR/
          fi

          # Copy nginx config
          cp $NGINX_CONF /etc/nginx/nginx.conf
        '';

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          ExecStartPre = "";
          ExecStart = "${pkg}/bin/youtubecast-start";
          Restart = "on-failure";
          RuntimeDirectory = "youtubecast";
        };
      };

      # Nginx is started by the wrapper script, so disable the default nginx service
      # unless explicitly enabled by the user
      networking.firewall.allowedTCPPorts = mkIf (!config.services.nginx.enable) [ (toInt (toString cfg.port)) ];
    }
  );
}
