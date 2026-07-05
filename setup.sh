#!/data/data/com.termux/files/usr/bin/bash
# setup.sh — One-tap installer for OpenReader on Android
# Run in Termux:  curl -sL <url>/setup.sh | bash
# Or clone repo:  git clone https://github.com/aswanthwuhan/openreader-android.git && cd openreader-android && bash setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"

echo "========================================="
echo "  OpenReader Android Installer"
echo "========================================="
echo ""

# ── Step 1: Termux packages ──────────────────────────────────────────
echo "[1/8] Installing Termux packages..."
pkg update -y && pkg install -y proot-distro git curl patch

# ── Step 2: Install proot Ubuntu ─────────────────────────────────────
echo "[2/8] Installing proot Ubuntu..."
if proot-distro list 2>&1 | grep -q "ubuntu"; then
  echo "  Already installed, skipping..."
else
  proot-distro install ubuntu
fi

# ── Step 3: Setup inside proot ───────────────────────────────────────
echo "[3/8] Setting up Ubuntu packages (Node.js, Python, pnpm)..."
proot-distro login ubuntu -- bash -c '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Node.js 22
if ! command -v node &>/dev/null; then
  echo "  Installing Node.js 22..."
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
  apt-get install -y -qq nodejs >/dev/null 2>&1
fi
echo "  Node: $(node -v)"

# pnpm
if ! command -v pnpm &>/dev/null; then
  npm install -g pnpm >/dev/null 2>&1
fi
echo "  pnpm: $(pnpm -v)"

# Python
if ! command -v python3 &>/dev/null; then
  apt-get install -y -qq python3-pip python3-venv python3-dev >/dev/null 2>&1
fi
echo "  Python: $(python3 --version)"

# uv
if [ ! -f "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi
echo "  uv: ok"
'

# ── Step 4: Clone OpenReader ─────────────────────────────────────────
echo "[4/8] Cloning OpenReader..."
proot-distro login ubuntu -- bash -c '
if [ ! -d /root/openreader ]; then
  cd /root
  git clone https://github.com/richardr1126/openreader.git
fi
cd /root/openreader
pnpm install --frozen-lockfile 2>/dev/null || pnpm install
'

# ── Step 5: Copy patches into proot and apply ────────────────────────
echo "[5/8] Applying Android patches..."

# Copy patches into proot via tmp
PATCHES_TMP="$HOME/openreader-patches"
rm -rf "$PATCHES_TMP"
mkdir -p "$PATCHES_TMP"
cp "$PATCHES_DIR"/*.patch "$PATCHES_TMP/"

proot-distro login ubuntu -- bash -c '
cd /root/openreader

TERMUX_HOME="/data/data/com.termux/files/home"
for p in "$TERMUX_HOME/openreader-patches"/*.patch; do
  [ -f "$p" ] || continue
  name=$(basename "$p")
  if patch -f -p1 --dry-run < "$p" >/dev/null 2>&1; then
    patch -p1 < "$p"
    echo "  Applied: $name"
  else
    echo "  Skipped: $name (already applied)"
  fi
done

rm -rf "$TERMUX_HOME/openreader-patches"
'

# ── Step 6: Setup KittenTTS ──────────────────────────────────────────
echo "[6/8] Setting up KittenTTS..."
proot-distro login ubuntu -- bash -c '
if [ ! -d /root/KittenTTS-FastAPI ]; then
  cd /root
  git clone https://github.com/thewh1teagle/KittenTTS.git KittenTTS-FastAPI
fi
cd /root/KittenTTS-FastAPI
source $HOME/.local/bin/env
uv sync 2>/dev/null || echo "  Note: may need manual uv sync"
'

# ── Step 7: Download model ───────────────────────────────────────────
echo "[7/8] Downloading PP-DocLayoutV3 ONNX model (~142MB)..."
proot-distro login ubuntu -- bash -c '
MODEL_DIR="/root/openreader/docstore/model"
mkdir -p "$MODEL_DIR"
BASE_URL="https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX/resolve/main"
FILES=(
  "PP-DocLayoutV3.onnx"
  "PP-DocLayoutV3.onnx.data"
  "config.json"
  "pp-doclayoutv3.config.json"
  "pp-doclayoutv3.preprocessor_config.json"
  "preprocessor_config.json"
  "pp-doclayoutv3.LICENSE.txt"
)
for f in "${FILES[@]}"; do
  if [ -f "$MODEL_DIR/$f" ]; then
    echo "  [skip] $f"
  else
    echo "  [download] $f ..."
    curl -fSL "$BASE_URL/$f" -o "$MODEL_DIR/$f"
  fi
done
echo "  Model ready"
'

# ── Step 8: Configure .env ───────────────────────────────────────────
echo "[8/8] Configuring environment..."
proot-distro login ubuntu -- bash -c '
cd /root/openreader
if [ ! -f .env ]; then
  AUTH_SECRET=$(openssl rand -hex 32)
  cat > .env << EOF
AUTH_SECRET=$AUTH_SECRET
BASE_URL=http://localhost:3004
USE_ANONYMOUS_AUTH_SESSIONS=true
ADMIN_EMAILS=admin@localhost
API_BASE=http://127.0.0.1:8005/v1
EOF
  echo "  .env created"
else
  echo "  .env exists, skipping"
fi
'

# ── Copy scripts to Termux home ──────────────────────────────────────
echo ""
echo "Installing start/stop scripts..."
cp "$SCRIPT_DIR/start-openreader.sh" "$HOME/"
cp "$SCRIPT_DIR/stop-openreader.sh" "$HOME/"
chmod +x "$HOME/start-openreader.sh" "$HOME/stop-openreader.sh"

echo ""
echo "========================================="
echo "  Setup complete!"
echo ""
echo "  Start:  ~/start-openreader.sh"
echo "  Stop:   ~/stop-openreader.sh"
echo "  Open:   http://localhost:3004"
echo "========================================="
