#!/data/data/com.termux/files/usr/bin/bash
# start-openreader.sh

echo "Stopping old services..."
kill -9 $(pgrep proot) 2>/dev/null
kill -9 $(pgrep nats-server) 2>/dev/null
kill -9 $(pgrep seaweedfs) 2>/dev/null
sleep 3
fuser -k 3004/tcp 8333/tcp 8081/tcp 4222/tcp 8005/tcp 8222/tcp 8223/tcp 2>/dev/null
sleep 2

echo "Starting KittenTTS..."
setsid proot-distro login ubuntu --shared-tmp -- bash -c '
cd /root/KittenTTS-FastAPI
source $HOME/.local/bin/env
KITTEN_SERVER_HOST=127.0.0.1 KITTEN_SERVER_PORT=8005 uv run src/server.py
' > ~/kittentts.log 2>&1 &

echo "Waiting for KittenTTS to start..."
sleep 25

echo "Starting OpenReader (embedded mode)..."
setsid proot-distro login ubuntu --shared-tmp -- bash -c '
set -e
cd /root/openreader
export UV_USE_IO_URING=0
export BASE_URL=http://localhost:3004
exec pnpm dev
' > ~/openreader.log 2>&1 &

echo "Waiting for bootstrap to start all services..."
sleep 60

echo ""
echo "============================================"
echo "  OpenReader + KittenTTS running!"
echo "  Open http://localhost:3004"
echo "  TTS: http://localhost:8005"
echo "============================================"
