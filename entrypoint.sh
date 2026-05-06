#!/bin/sh
set -e

CONFIG_DIR=/etc/xray
CONFIG_FILE="$CONFIG_DIR/config.json"
CLIENT_FILE="$CONFIG_DIR/client.txt"
mkdir -p "$CONFIG_DIR"

PORT="${PORT:-80}"
WS_PATH="${WS_PATH:-/ray}"
SERVER_HOST="${SERVER_HOST:-YOUR_SERVER_IP}"

if [ ! -f "$CONFIG_FILE" ]; then
    UUID="${UUID:-$(xray uuid)}"

    cat > "$CONFIG_FILE" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $PORT,
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
    cat > "$CLIENT_FILE" <<EOF
=== VLESS WebSocket Client Info ===
UUID:    $UUID
Host:    $SERVER_HOST
Port:    $PORT
Path:    $WS_PATH
Network: ws
TLS:     none

Import URL (replace $SERVER_HOST with your server's public IP/domain if needed):
vless://$UUID@$SERVER_HOST:$PORT?encryption=none&type=ws&path=$ENCODED_PATH&host=$SERVER_HOST#xray-vless-ws
EOF
fi

cat "$CLIENT_FILE"
echo
exec xray run -config "$CONFIG_FILE"
