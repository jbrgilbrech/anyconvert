#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$ROOT_DIR/docs/vendor/ffmpeg" "$ROOT_DIR/docs/vendor/ffmpeg-util"
cp -R "$ROOT_DIR/node_modules/@ffmpeg/ffmpeg/dist/esm/." "$ROOT_DIR/docs/vendor/ffmpeg/"
cp -R "$ROOT_DIR/node_modules/@ffmpeg/util/dist/esm/." "$ROOT_DIR/docs/vendor/ffmpeg-util/"
cp "$ROOT_DIR/node_modules/@ffmpeg/core/dist/esm/ffmpeg-core.js" "$ROOT_DIR/docs/vendor/ffmpeg/"
cp "$ROOT_DIR/node_modules/@ffmpeg/core/dist/esm/ffmpeg-core.wasm" "$ROOT_DIR/docs/vendor/ffmpeg/"

echo "Synced browser vendor assets into docs/vendor"
