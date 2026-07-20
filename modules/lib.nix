{ pkgs }:

# Generate settings.json content from direct values or file paths
genSettings = {
  youtubeApiKey ? ""
, youtubeApiKeyFile ? null
, downloadVideos ? false
, maximumCompatibility ? false
, highestQuality ? false
, cacheTimeToLive ? 1200
, minimumVideoDuration ? 180
}:
let
  key = if youtubeApiKeyFile != null
    then pkgs.lib.readFile youtubeApiKeyFile
    else youtubeApiKey;
  dl = if downloadVideos then "true" else "false";
  mc = if maximumCompatibility then "true" else "false";
  hq = if highestQuality then "true" else "false";
in
pkgs.runCommand "settings.json" { } ''
  cat > $out <<EOF
{
  "youtubeApiKey": "${key}",
  "downloadVideos": ${dl},
  "maximumCompatibility": ${mc},
  "highestQuality": ${hq},
  "cacheTimeToLive": "${toString cacheTimeToLive}",
  "minimumVideoDuration": "${toString minimumVideoDuration}"
}
EOF
''

# Generate nginx config with the specified port
genNginxConfig = { port }:
  pkgs.runCommand "nginx.conf" { } ''
    sed 's/${port}/${toString port}/g' ${./../nginx.conf} > $out
  ''

in {
  inherit genSettings genNginxConfig;
}
