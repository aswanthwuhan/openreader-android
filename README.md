# OpenReader on Android

Run [OpenReader](https://github.com/richardr1126/openreader) (self-hosted audiobook/document reader with TTS) on Android using Termux + proot Ubuntu.

## What's Included

| Service | Port | Description |
|---------|------|-------------|
| OpenReader (Next.js) | 3004 | Web UI for document management |
| Compute Worker | 8081 | PDF parsing (PP-DocLayoutV3 ONNX) + Whisper alignment |
| KittenTTS | 8005 | Lightweight ONNX-based TTS server |
| SeaweedFS | 8333 | Embedded S3-compatible object storage |
| NATS | 4222 | Message queue for job processing |

## Prerequisites

- Android device with [Termux](https://f-droid.org/en/packages/com.termux/) installed
- ~2GB free storage
- Internet connection (for initial setup only)

## Quick Start

### 1. Install Termux packages

```bash
pkg update && pkg upgrade -y
pkg install proot-distro git curl -y
```

### 2. Install proot Ubuntu

```bash
proot-distro install ubuntu
proot-distro login ubuntu
```

### 3. Setup Node.js + pnpm

```bash
# Inside proot
apt update && apt install -y curl
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g pnpm
```

### 4. Setup Python (for KittenTTS)

```bash
# Inside proot
apt install -y python3-pip python3-venv python3-dev
python3 -m venv ~/paddle-venv
source ~/paddle-venv/bin/activate
pip install uv
```

### 5. Clone OpenReader

```bash
# Inside proot
cd /root
git clone https://github.com/richardr1126/openreader.git
cd openreader
pnpm install
```

### 6. Setup KittenTTS

```bash
# Inside proot
cd /root
git clone https://github.com/thewh1teagle/KittenTTS.git KittenTTS-FastAPI
cd KittenTTS-FastAPI
source ~/paddle-venv/bin/activate
uv sync
```

### 7. Configure environment

Copy `.env.example` to `/root/openreader/.env` inside proot and set your `AUTH_SECRET`:

```bash
# Inside proot
cp /path/to/.env.example /root/openreader/.env
# Generate a random secret:
sed -i "s/CHANGE_ME_TO_A_RANDOM_STRING/$(openssl rand -hex 32)/" /root/openreader/.env
```

### 8. Copy startup scripts

From Termux:

```bash
cp start-openreader.sh ~/
cp stop-openreader.sh ~/
chmod +x ~/start-openreader.sh ~/stop-openreader.sh
```

### 9. Start everything

```bash
~/start-openreader.sh
```

Wait ~60 seconds for all services to start, then open `http://localhost:3004` in your browser.

### 10. Stop everything

```bash
~/stop-openreader.sh
```

## How It Works

- **proot Ubuntu** provides a full Linux environment without root access
- **OpenReader bootstrap CLI** (`pnpm dev`) auto-starts embedded SeaweedFS, NATS, and compute worker
- **PP-DocLayoutV3 ONNX model** (~142MB) is downloaded automatically on first PDF upload for layout detection
- **KittenTTS** provides lightweight ONNX-based text-to-speech (~25MB model, no PyTorch required)
- **setsid** ensures background processes survive shell exit

## Architecture

```
Termux
  └── proot-distro (Ubuntu 26.04)
       ├── KittenTTS (port 8005)
       │   └── ONNX TTS model
       └── OpenReader bootstrap (pnpm dev)
            ├── Next.js app (port 3004)
            ├── Compute Worker (port 8081)
            │   ├── PP-DocLayoutV3 ONNX (layout detection)
            │   ├── pdf.js (text extraction)
            │   └── Whisper (audio alignment)
            ├── SeaweedFS (port 8333)
            └── NATS (port 4222)
```

## Troubleshooting

### Services won't start
```bash
# Kill all proot processes and free ports
fuser -k 3004/tcp 8333/tcp 8081/tcp 4222/tcp 8005/tcp 2>/dev/null
kill -9 $(pgrep proot) 2>/dev/null
sleep 2
~/start-openreader.sh
```

### Port 3004 already in use
```bash
fuser -k 3004/tcp
```

### Check logs
```bash
tail -50 ~/openreader.log    # OpenReader logs
tail -20 ~/kittentts.log     # KittenTTS logs
```

## Credits

- [OpenReader](https://github.com/richardr1126/openreader) - Self-hosted audiobook/document reader
- [KittenTTS](https://github.com/thewh1teagle/KittenTTS) - Lightweight ONNX TTS
- [PP-DocLayoutV3](https://huggingface.co/PaddlePaddle/PP-DocLayoutV3) - Document layout detection model
