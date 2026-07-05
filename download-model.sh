#!/usr/bin/env bash
# Download PP-DocLayoutV3 ONNX model files for OpenReader compute worker
# Source: https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX (Apache-2.0)

set -euo pipefail

MODEL_DIR="/root/openreader/docstore/model"
BASE_URL="https://huggingface.co/Bei0001/PP-DocLayoutV3-ONNX/resolve/main"

mkdir -p "$MODEL_DIR"

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
    echo "  [skip] $f (exists)"
  else
    echo "  [download] $f ..."
    curl -fSL "$BASE_URL/$f" -o "$MODEL_DIR/$f"
  fi
done

echo "Done. Model files in $MODEL_DIR"
