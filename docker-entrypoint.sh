#!/bin/sh
set -e

PORT="${PXT_PORT:-3232}"
WSPORT="${PXT_WSPORT:-3233}"
TOKEN="${PXT_LOCAL_TOKEN:-offline}"

# Fixed local token so the editor URL stays the same across restarts.
# The browser needs it once (http://localhost:3232/#local_token=$TOKEN) to use
# the local server: offline hex cache and saving projects to /app/projects.
mkdir -p "$HOME/.pxt"
printf '{\n    "noAutoStart": true,\n    "localToken": "%s"\n}\n' "$TOKEN" > "$HOME/.pxt/config.json"

case "$1" in
  serve)
    shift
    # --just: serve the target built into the image without rebuilding
    exec pxt serve --just --noBrowser --noauth \
      --hostname 0.0.0.0 --port "$PORT" --wsport "$WSPORT" "$@"
    ;;
  serve-full)
    shift
    exec pxt serve --noBrowser --noauth \
      --hostname 0.0.0.0 --port "$PORT" --wsport "$WSPORT" "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
