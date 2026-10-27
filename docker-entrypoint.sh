#!/bin/sh
set -e

PORT="${PXT_PORT:-3232}"
WSPORT="${PXT_WSPORT:-3233}"
TOKEN="${PXT_LOCAL_TOKEN:-offline}"
HTTPS_PORT="${PXT_HTTPS_PORT:-3443}"
TLS_DIR="${PXT_TLS_DIR:-/tls}"
SITE=/app/built/packaged

# Fixed local token so the editor URL stays the same across restarts.
# The browser needs it once (http://localhost:3232/#local_token=$TOKEN) to use
# the local server: offline hex cache and saving projects to /app/projects.
mkdir -p "$HOME/.pxt"
printf '{\n    "noAutoStart": true,\n    "localToken": "%s"\n}\n' "$TOKEN" > "$HOME/.pxt/config.json"

# Builds the subjectAltName list from localhost plus PXT_TLS_HOSTS. Hosts the
# CA's name constraints don't allow are skipped, since browsers would reject them.
tls_san() {
  san="DNS:localhost,IP:127.0.0.1"
  for host in $(echo "${PXT_TLS_HOSTS:-}" | tr ',' ' '); do
    case "$host" in
      localhost|127.0.0.1) ;;
      10.*|127.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*)
        san="$san,IP:$host" ;;
      *.local|*.lan|*.home.arpa|*.internal)
        san="$san,DNS:$host" ;;
      *)
        echo "TLS: skipping $host (use a private IP or a name ending in .local, .lan, .home.arpa or .internal)" >&2 ;;
    esac
  done
  echo "$san"
}

# Creates a local CA once (kept in the $TLS_DIR volume) and a server
# certificate for the hosts in PXT_TLS_HOSTS. The CA is name-constrained to
# private IPs and local names, so even a leaked key can't sign public sites.
tls_setup() {
  mkdir -p "$TLS_DIR"
  umask 077
  if [ ! -f "$TLS_DIR/ca.key" ] || [ ! -f "$TLS_DIR/ca.crt" ]; then
    echo "TLS: creating local CA"
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
      -subj "/CN=pxt-microbit local CA" \
      -keyout "$TLS_DIR/ca.key" -out "$TLS_DIR/ca.crt" \
      -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
      -addext "keyUsage=critical,keyCertSign,cRLSign" \
      -addext "nameConstraints=critical,permitted;IP:10.0.0.0/255.0.0.0,permitted;IP:172.16.0.0/255.240.0.0,permitted;IP:192.168.0.0/255.255.0.0,permitted;IP:127.0.0.0/255.0.0.0,permitted;DNS:localhost,permitted;DNS:local,permitted;DNS:lan,permitted;DNS:home.arpa,permitted;DNS:internal" \
      2>/dev/null
    rm -f "$TLS_DIR/server.crt"
  fi

  san="$(tls_san)"
  # Reissue when the hosts change or the certificate expires within 30 days
  if [ ! -f "$TLS_DIR/server.crt" ] || [ "$(cat "$TLS_DIR/san.txt" 2>/dev/null)" != "$san" ] \
    || ! openssl x509 -checkend 2592000 -noout -in "$TLS_DIR/server.crt" >/dev/null; then
    echo "TLS: issuing server certificate for $san"
    printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=%s\n' \
      "$san" > "$TLS_DIR/server.ext"
    openssl req -newkey rsa:2048 -nodes -subj "/CN=pxt-microbit" \
      -keyout "$TLS_DIR/server.key" -out "$TLS_DIR/server.csr" 2>/dev/null
    openssl x509 -req -sha256 -days 397 -in "$TLS_DIR/server.csr" \
      -CA "$TLS_DIR/ca.crt" -CAkey "$TLS_DIR/ca.key" -set_serial "0x$(openssl rand -hex 16)" \
      -extfile "$TLS_DIR/server.ext" -out "$TLS_DIR/server.crt" 2>/dev/null
    rm -f "$TLS_DIR/server.csr" "$TLS_DIR/server.ext"
    echo "$san" > "$TLS_DIR/san.txt"
  fi
  umask 022

  # Only the public CA certificate is published, for clients to install
  cp "$TLS_DIR/ca.crt" "$SITE/rootCA.crt"
  echo "TLS: install the CA from http://<host IP>:$PORT/rootCA.crt"
  echo "TLS: CA $(openssl x509 -noout -fingerprint -sha256 -in "$TLS_DIR/ca.crt")"
}

case "$1" in
  static)
    shift
    # Static editor from built/packaged: works from any machine on the network
    # (no token), uses the bundled hex cache, saves projects in each browser.
    # HTTPS on $HTTPS_PORT gives browsers on other machines a secure context,
    # so they can flash over WebUSB. A certificate mounted at /certs (e.g. from
    # mkcert) takes precedence over the generated one.
    if [ -f /certs/cert.pem ] && [ -f /certs/key.pem ]; then
      CERT=/certs/cert.pem KEY=/certs/key.pem
    else
      tls_setup
      CERT="$TLS_DIR/server.crt" KEY="$TLS_DIR/server.key"
    fi
    http-server "$SITE" -a 0.0.0.0 -p "$HTTPS_PORT" -c-1 \
      -S -C "$CERT" -K "$KEY" "$@" &
    exec http-server "$SITE" -a 0.0.0.0 -p "$PORT" -c-1 "$@"
    ;;
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
