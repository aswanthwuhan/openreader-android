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

### 6. Apply Android compatibility patches

```bash
# Inside proot — from proot home
cd /root/openreader
```

These files were modified from upstream for proot compatibility:

#### a) `next.config.ts` — Webpack .mjs fix + external packages

```typescript
// Add to webpack config to fix __webpack_require__.U error in proot
config.module.rules.push({
  test: /\.mjs$/,
  include: /node_modules/,
  resolve: { fullySpecified: false },
});

// Add serverExternalPackages to prevent bundling issues
const serverExternalPackages = [
  '@napi-rs/canvas',
  'better-sqlite3',
  'ffmpeg-static',
  'pdfjs-dist',
];
```

#### b) `packages/compute-worker/src/inference/runtime.ts` — ONNX model import fix

```typescript
// Changed: ensureModel → ensurePdfLayoutModel (import alias fix)
import { ensureModel as ensurePdfLayoutModel } from './pdf/model';
```

#### c) `packages/bootstrap/src/cli.mjs` — Health check timeout increase

```javascript
// Changed: 30s → 90s timeout for compute worker health check
// Needed because Android proot is slower than Docker
```

#### d) `src/lib/client/pdf.ts` — CDN fallback for pdfjs-dist worker

```typescript
// Added: CDN fallback when local pdfjs-dist worker fails to load
// Required because proot symlink resolution differs from Docker
```

#### e) `src/lib/server/admin/seed.ts` — Anonymous auth for local use

```typescript
// Added support for USE_ANONYMOUS_AUTH_SESSIONS=true
// Allows access without login on localhost
```

#### f) `packages/compute-worker/src/inference/pdf/simple-layout.ts` (new)

```typescript
// Improved text layout heuristics: column detection, line merging,
// font-size-based labels. Used as fallback when ONNX layout fails.
```

#### g) `packages/compute-worker/src/inference/pdf/parse-simple.ts` (new)

```typescript
// Simplified PDF parser using simple-layout.ts with debug logging.
// Alternative entry point when ONNX parser is too heavy for Android.
```

### 7. Setup KittenTTS

```bash
# Inside proot
cd /root
git clone https://github.com/thewh1teagle/KittenTTS.git KittenTTS-FastAPI
cd KittenTTS-FastAPI
source ~/paddle-venv/bin/activate
uv sync
```

### 8. Configure environment

```bash
# Inside proot
cd /root/openreader

# Create .env with these values:
cat > .env << 'EOF'
AUTH_SECRET=$(openssl rand -hex 32)
BASE_URL=http://localhost:3004
USE_ANONYMOUS_AUTH_SESSIONS=true
ADMIN_EMAILS=admin@localhost
API_BASE=http://127.0.0.1:8005/v1
EOF
```

Key settings:
- `AUTH_SECRET` — random hex string (auto-generated)
- `BASE_URL` — must match the port (3004, not 3003)
- `USE_ANONYMOUS_AUTH_SESSIONS=true` — skip login on localhost
- `API_BASE` — points to local KittenTTS server

### 9. Copy startup scripts

From Termux (not proot):

```bash
cp start-openreader.sh ~/
cp stop-openreader.sh ~/
chmod +x ~/start-openreader.sh ~/stop-openreader.sh
```

### 10. Download layout model

```bash
# Inside proot
bash /root/openreader-setup/download-model.sh
```

This downloads the PP-DocLayoutV3 ONNX model (~142MB) from HuggingFace into `/root/openreader/docstore/model/`. Files:

| File | Size | Description |
|------|------|-------------|
| `PP-DocLayoutV3.onnx` | 5MB | Model weights (main) |
| `PP-DocLayoutV3.onnx.data` | 131MB | External weights data |
| `config.json` | 2.5KB | Model architecture config |
| `pp-doclayoutv3.config.json` | 2.5KB | Duplicate config |
| `pp-doclayoutv3.preprocessor_config.json` | 575B | Image preprocessing config |
| `preprocessor_config.json` | 575B | Duplicate preprocessor config |
| `pp-doclayoutv3.LICENSE.txt` | 195B | Apache-2.0 license |

Source: [Bei0001/PP-DocLayoutV3-ONNX](https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX) (Apache-2.0)

### 11. Start everything

```bash
~/start-openreader.sh
```

What the start script does:
1. Kills any existing proot processes and frees ports
2. Starts KittenTTS in background (port 8005) via `setsid proot-distro login`
3. Waits 25 seconds for TTS to initialize
4. Starts OpenReader bootstrap via `pnpm dev` (auto-starts SeaweedFS, NATS, compute worker)
5. Waits 50 seconds for all services to be healthy

Wait ~60 seconds total, then open `http://localhost:3004` in your browser.

### 12. Stop everything

```bash
~/stop-openreader.sh
```

## How It Works

- **proot Ubuntu** provides a full Linux environment without root access
- **OpenReader bootstrap CLI** (`pnpm dev`) auto-starts embedded SeaweedFS, NATS, and compute worker
- **PP-DocLayoutV3 ONNX model** (~142MB) is pre-downloaded via `download-model.sh` for layout detection (from [Bei0001/PP-DocLayoutV3-ONNX](https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX), Apache-2.0)
- **KittenTTS** provides lightweight ONNX-based text-to-speech (~25MB model, no PyTorch required)
- **setsid** ensures background processes survive shell exit
- **UV_USE_IO_URING=0** prevents libuv assertion crash in proot

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

## Known Limitations

- **Turbopack disabled** — crashes in proot with `Invalid symlink` error; Webpack works with `.mjs` fix
- **Port 3003 ghost** — always returns HTTP 200 even when nothing is running; use port 3004 instead
- **Compute worker crashes** — if the compute worker dies, bootstrap shuts down ALL services (restart needed)
- **PaddlePaddle/PaddleX** — cannot run on aarch64 proot (SIGSEGV in native kernels)
- **ExecuTorch** — nightly builds have ABI mismatch on aarch64; no fix without rebuilding from source
- **RAM** — Android devices with <3GB free may struggle with PDF parsing + TTS simultaneously

## Troubleshooting

### Services won't start
```bash
# Kill all proot processes and free ports
fuser -k 3004/tcp 8333/tcp 8081/tcp 4222/tcp 8005/tcp 2>/dev/null
kill -9 $(pgrep proot) 2>/dev/null
sleep 2
~/start-openreader.sh
```

### Port already in use
```bash
fuser -k 3004/tcp  # or whichever port
```

### Check logs
```bash
tail -50 ~/openreader.log    # OpenReader + compute worker + SeaweedFS + NATS
tail -20 ~/kittentts.log     # KittenTTS server
```

### Restart from clean state
```bash
~/stop-openreader.sh
sleep 3
~/start-openreader.sh
```

## Credits

- [OpenReader](https://github.com/richardr1126/openreader) — Self-hosted audiobook/document reader
- [KittenTTS](https://github.com/thewh1teagle/KittenTTS) — Lightweight ONNX TTS
- [PP-DocLayoutV3](https://huggingface.co/PaddlePaddle/PP-DocLayoutV3) — Document layout detection model
- [Bei0001/PP-DocLayoutV3-ONNX](https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX) — ONNX export (Apache-2.0)
