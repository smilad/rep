#!/bin/sh
set -e

CONFIG_DIR=/etc/xray
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

# What the container binds to (Runflare/PaaS often inject $PORT).
LISTEN_PORT="${PORT:-80}"
WS_PATH="${WS_PATH:-/ray}"

# What the phone connects to. On Runflare these are the public domain
# and the public TLS port (443). Locally these match LISTEN_PORT.
PUBLIC_HOST="${PUBLIC_HOST:-${SERVER_HOST:-YOUR_DOMAIN}}"
PUBLIC_PORT="${PUBLIC_PORT:-443}"
TLS_MODE="${TLS_MODE:-tls}"   # "tls" when behind a TLS-terminating proxy, else "none"

# Persist UUID so it doesn't change between restarts.
UUID_FILE="$CONFIG_DIR/uuid"
if [ -n "$UUID" ]; then
    echo "$UUID" > "$UUID_FILE"
elif [ ! -f "$UUID_FILE" ]; then
    xray uuid > "$UUID_FILE"
fi
UUID=$(cat "$UUID_FILE")

cat > "$CONFIG_FILE" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $LISTEN_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "$UUID" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "$WS_PATH" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

ENCODED_PATH=$(printf '%s' "$WS_PATH" | sed 's|/|%2F|g')
SECURITY_PARAM=""
SNI_PARAM=""
if [ "$TLS_MODE" = "tls" ]; then
    SECURITY_PARAM="&security=tls&fp=chrome&sni=$PUBLIC_HOST&alpn=http%2F1.1"
fi

CLIENT_URL="vless://$UUID@$PUBLIC_HOST:$PUBLIC_PORT?encryption=none&type=ws&path=$ENCODED_PATH&host=$PUBLIC_HOST$SECURITY_PARAM#xray-vless-ws"

echo "============================================================"
echo "  VLESS WebSocket"
echo "  UUID:        $UUID"
echo "  Public host: $PUBLIC_HOST"
echo "  Public port: $PUBLIC_PORT  (TLS=$TLS_MODE)"
echo "  Listen port: $LISTEN_PORT (inside container)"
echo "  WS path:     $WS_PATH"
echo "------------------------------------------------------------"
echo "$CLIENT_URL"
echo "============================================================"

exec xray run -config "$CONFIG_FILE"
