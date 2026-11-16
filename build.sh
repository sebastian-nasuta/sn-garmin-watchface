#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_BIN="${CONNECTIQ_SDK_BIN:-$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.3.0-2026-10-20-95888f262/bin}"
DEV_KEY="${CONNECTIQ_DEV_KEY:-$HOME/.Garmin/developer_key.der}"

mkdir -p "$ROOT_DIR/bin"

"$SDK_BIN/monkeyc" -d fr970 -f "$ROOT_DIR/monkey.jungle" -o "$ROOT_DIR/bin/sn-watchface.prg" -y "$DEV_KEY" -w
"$SDK_BIN/monkeyc" -e -f "$ROOT_DIR/monkey.jungle" -o "$ROOT_DIR/bin/sn-watchface.iq" -y "$DEV_KEY" -w
"$SDK_BIN/monkeyc" -e -f "$ROOT_DIR/monkey-beta.jungle" -o "$ROOT_DIR/bin/sn-watchface-beta.iq" -y "$DEV_KEY" -w
