#!/bin/bash

echo "==============================="
echo "🚀 STARTING DEPLOYMENT PROCESS"
echo "==============================="

echo "📦 Install tools pendukung (htop, jq)..."
#sudo apt update
sudo apt install -y htop jq

echo "⬇️ Install rclone..."
curl https://rclone.org/install.sh | sudo bash

# ========================
# KONFIGURASI RCLONE
# ========================
REMOTE_NAME="gdrive"
TOKEN_FILE="./token.json"
RCLONE_CONF_PATH="$HOME/.config/rclone/rclone.conf"
DEST_FOLDER="$(pwd)"
GDRIVE_FOLDER="Project-Tutorial/n8n"
IMAGE_FILE="n8n.tar"

echo ""
echo "==============================="
echo "⚙️  CONFIGURING RCLONE"
echo "==============================="

if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ File token.json tidak ditemukan di path: $TOKEN_FILE"
  exit 1
fi

echo "⚙️ Menyiapkan rclone.conf..."
mkdir -p "$(dirname "$RCLONE_CONF_PATH")"
TOKEN=$(jq -c . "$TOKEN_FILE")

cat > "$RCLONE_CONF_PATH" <<EOF
[$REMOTE_NAME]
type = drive
scope = drive
token = $TOKEN
EOF

echo "✅ rclone.conf berhasil dibuat."

# ========================
# DOWNLOAD IMAGE n8n.tar
# ========================
echo ""
echo "==============================="
echo "⬇️  DOWNLOADING n8n.tar FROM GOOGLE DRIVE"
echo "==============================="

echo "📁 Folder Drive: $GDRIVE_FOLDER"
echo "📁 Tujuan: $DEST_FOLDER"

rclone copy --config="$RCLONE_CONF_PATH" "$REMOTE_NAME:$GDRIVE_FOLDER/$IMAGE_FILE" "$DEST_FOLDER" --progress

if [ $? -ne 0 ]; then
  echo "❌ Gagal men-download n8n.tar dari Google Drive!"
  exit 1
fi

echo "✅ Download selesai."

# ========================
# LOAD DOCKER IMAGE
# ========================
echo ""
echo "==============================="
echo "🐳  LOADING DOCKER IMAGE"
echo "==============================="

if [ ! -f "$IMAGE_FILE" ]; then
  echo "❌ File $IMAGE_FILE tidak ditemukan setelah download!"
  exit 1
fi

mkdir n8n_data

docker load -i "$IMAGE_FILE"

echo "🏷️ Menandai image menjadi custom-n8n:latest ..."
docker tag n8nio/n8n:latest custom-n8n:latest

echo "✅ Image berhasil diload & ditag."

# ========================
# MEMBUAT DOCKER-COMPOSE
# ========================
echo ""
echo "==============================="
echo "📝  GENERATING docker-compose.yml"
echo "==============================="

cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  n8n:
    image: custom-n8n:latest
    container_name: n8n
    restart: always
    networks:
      - n8n_net
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.obc-crypto.com
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.obc-crypto.com
      - N8N_EDITOR_BASE_URL=https://n8n.obc-crypto.com
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
    volumes:
      - ./n8n_data:/home/node/.n8n

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: always
    networks:
      - n8n_net
    command: >
      tunnel --no-autoupdate run --token
      XXX

networks:
  n8n_net:
    driver: bridge
EOF

echo "✅ docker-compose.yml berhasil dibuat."

# ========================
# DEPLOY DOCKER COMPOSE
# ========================
echo ""
echo "==============================="
echo "🚀  STARTING DOCKER COMPOSE"
echo "==============================="

docker compose up -d

if [ $? -eq 0 ]; then
    echo "🎉 Deploy berhasil!"
    echo "🌐 Aplikasi berjalan di port 5678"
else
    echo "❌ Deploy gagal!"
fi

ping 8.8.8.8
