#!/usr/bin/env bash
set -e

APP_DIR="${APP_DIR:-/app}"
CONTENT_DIR="${YOUTUBECAST_CONTENT_DIR:-/var/lib/youtubecast}"
NGINX_PORT="${YOUTUBECAST_PORT:-3000}"
BUN_PORT=3001

# Create content directory if it doesn't exist
mkdir -p "$CONTENT_DIR"

# Write nginx config with the correct port
NGINX_PKG=$(find /nix/store -maxdepth 1 -name "nginx-*" -type d 2>/dev/null | head -1)
sed -e "s/\${port}/$NGINX_PORT/" -e "s|\${nginx}|$NGINX_PKG|" "$APP_DIR/nginx.conf" > /tmp/youtubecast-nginx.conf

# Start nginx
nginx -c /tmp/youtubecast-nginx.conf -g "daemon off;" &

# Start Bun application
exec bun run "$APP_DIR/src/index.ts"
