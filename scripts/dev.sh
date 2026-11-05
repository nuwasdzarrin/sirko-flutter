#!/usr/bin/env bash
# Jalankan Sirko (debug) di HP lewat ADB Wi-Fi — macOS/Linux.
# Pasangan Windows: scripts/dev.ps1. Panduan lengkap: SETUP.md.
#
#   scripts/dev.sh [--connect IP:PORT] [--api URL] [--build-only] [-- <arg flutter lain>]
#
# Prioritas URL backend: --api > env SIRKO_API_BASE > env/local.json
#                        > otomatis http://<IP-LAN-mesin-ini>:${SIRKO_API_PORT:-47321}
# Prioritas Flutter:     env FLUTTER_BIN > env/local.json "FLUTTER_BIN" > `flutter` di PATH
set -euo pipefail
cd "$(dirname "$0")/.."

CONNECT="" ; API="${SIRKO_API_BASE:-}" ; BUILD_ONLY=0 ; EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --connect) CONNECT="$2"; shift 2 ;;
    --api) API="$2"; shift 2 ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --) shift; EXTRA=("$@"); break ;;
    *) echo "Opsi tak dikenal: $1" >&2; exit 2 ;;
  esac
done

json_get() { # json_get <key> — baca string dari env/local.json (tanpa jq)
  [[ -f env/local.json ]] || return 0
  sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" env/local.json | head -1
}

FLUTTER="${FLUTTER_BIN:-$(json_get FLUTTER_BIN)}"; FLUTTER="${FLUTTER:-flutter}"
command -v "$FLUTTER" >/dev/null || { echo "Flutter tak ditemukan ($FLUTTER). Set FLUTTER_BIN di env/local.json." >&2; exit 1; }

# 1) Kunci versi Flutter — beda versi = pubspec.lock berubah = bentrok antar mesin.
WANT="$(tr -d '[:space:]' < .flutter-version)"
HAVE="$("$FLUTTER" --version 2>/dev/null | sed -nE 's/^Flutter ([0-9.]+).*/\1/p')"
if [[ "$HAVE" != "$WANT" ]]; then
  echo "✗ Flutter $HAVE, proyek mengunci $WANT (.flutter-version). Lihat SETUP.md." >&2; exit 1
fi

# 2) URL backend
[[ -z "$API" ]] && API="$(json_get SIRKO_API_BASE)"
if [[ -z "$API" ]]; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -n "$IP" ]] || { echo "IP LAN tak terdeteksi; pakai --api URL." >&2; exit 1; }
  API="http://$IP:${SIRKO_API_PORT:-47321}"
fi
echo "→ Flutter $HAVE · backend $API"

# 3) Debug build saja (APK di build/app/outputs/flutter-apk/app-debug.apk)
if [[ $BUILD_ONLY == 1 ]]; then
  exec "$FLUTTER" build apk --debug --target-platform android-arm64 --dart-define=SIRKO_API_BASE="$API" ${EXTRA[@]+"${EXTRA[@]}"}
fi

# 4) Sambungkan HP (ADB Wi-Fi) bila diminta, lalu jalankan dengan hot reload.
ADB="adb"; command -v adb >/dev/null || ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
DEVICE_ARGS=()
if [[ -n "$CONNECT" ]]; then
  "$ADB" connect "$CONNECT"
  DEVICE_ARGS=(-d "$CONNECT")
fi
exec "$FLUTTER" run --debug ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} --dart-define=SIRKO_API_BASE="$API" ${EXTRA[@]+"${EXTRA[@]}"}
