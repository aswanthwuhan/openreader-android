#!/data/data/com.termux/files/usr/bin/bash
# start-openreader.sh - Start OpenReader + KittenTTS on Android (Termux + proot)
set -e

echo "Stopping old services..."
kill -9 $(pgrep proot) 2>/dev/null; sleep 2
fuser -k 3004/tcp 2>/dev/null; fuser -k 8333/tcp 2>/dev/null
fuser -k 8081/tcp 2>/dev/null; fuser -k 4222/tcp 2>/dev/null
fuser -k 8005/tcp 2>/dev/null; sleep 1

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
sleep 50

echo ""
echo "============================================"
echo "  OpenReader + KittenTTS running!"
echo "  Open http://localhost:3004"
echo "  TTS: http://localhost:8005"
echo "============================================"
