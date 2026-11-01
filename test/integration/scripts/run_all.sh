#!/usr/bin/env bash
# Jalankan suite Maestro Sirko berurutan + rekam layar per flow.
# Pakai: bash test/integration/scripts/run_all.sh [pola-flow ...]
#   tanpa argumen  → semua flows/[0-9]*.yaml (urut nama)
#   dengan argumen → hanya flow yang cocok, mis. 01 02 04
# Hasil: test/integration/record/<YYYY-MM-DD_HHMMSS>/
#   videos/*.mp4  screenshots/*.png  report.xml (JUnit)  summary.txt  artifacts/ (log Maestro)
set -u
source "$(dirname "$0")/env.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/record/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$RUN/videos" "$RUN/screenshots" "$RUN/artifacts" "$RUN/junit"

cd "$ROOT/flows"
if [ $# -eq 0 ]; then
  FLOWS=$(ls [0-9]*.yaml | sort)
else
  FLOWS=$(for p in "$@"; do ls ${p}*.yaml 2>/dev/null; done | sort -u)
fi

# Preflight: paksa keyboard layar tampil. Setelah cold boot emulator bisa
# menganggap ada keyboard fisik → keyboard layar tak muncul → hideKeyboard
# Maestro jadi tombol Back (menutup dialog / keluar app).
adb -s "$DEVICE" shell settings put secure show_ime_with_hard_keyboard 1

APP_VER=$(adb -s "$DEVICE" shell dumpsys package com.sirko.app | grep -m1 versionName | tr -d ' \r')
{
  echo "Sirko — Maestro integration run"
  echo "Waktu   : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Device  : $DEVICE ($(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r'), API $(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r'))"
  echo "App     : $APP_VER"
  echo "Maestro : $(maestro --version 2>/dev/null | tail -1)"
  echo "----------------------------------------------------------------"
} > "$RUN/summary.txt"

PASS=0; FAIL=0; BUGS=0; FIXED=0
for f in $FLOWS; do
  base="${f%.yaml}"
  start=$(date +%s)
  if maestro --device "$DEVICE" test "$f" \
       --format junit --output "$RUN/junit/$base.xml" \
       --test-output-dir "$RUN/artifacts/$base" > "$RUN/artifacts/$base.log" 2>&1; then
    ok=1
  else
    ok=0
  fi
  # Flow 9x = regresi bug: meng-assert perilaku SEHARUSNYA. Gagal = bug masih ada.
  case "$base" in
    # BUG-01 = race intermiten: lulus belum tentu sudah diperbaiki.
    90_*) if [ $ok -eq 1 ]; then status="TAK-TERPICU"; else status="BUG"; BUGS=$((BUGS+1)); fi ;;
    9*) if [ $ok -eq 1 ]; then status="FIXED"; FIXED=$((FIXED+1)); else status="BUG"; BUGS=$((BUGS+1)); fi ;;
    *)  if [ $ok -eq 1 ]; then status="LULUS"; PASS=$((PASS+1)); else status="GAGAL"; FAIL=$((FAIL+1)); fi ;;
  esac
  dur=$(( $(date +%s) - start ))
  find "$RUN/artifacts/$base" -name "*.mp4" -exec cp {} "$RUN/videos/" \; 2>/dev/null
  find "$RUN/artifacts/$base" -path "*takeScreenshot*" -name "*.png" -exec cp {} "$RUN/screenshots/" \; 2>/dev/null
  # Screenshot otomatis Maestro pada langkah yang gagal (step-<n>-*.png terakhir)
  # → disalin dengan awalan GAGAL_ agar mudah ditemukan.
  if [ $ok -eq 0 ]; then
    last=$(find "$RUN/artifacts/$base" -path "*screenshots*" -name "step-*.png" | sort -V | tail -1)
    [ -n "$last" ] && cp "$last" "$RUN/screenshots/GAGAL_$base.png"
    reason=$(grep -E "FAILED|Assertion is false|not found" "$RUN/artifacts/$base.log" | grep -v "^Run " | tail -2 | tr '\n' ' ')
  else
    reason=""
  fi
  printf "%-42s %-6s %4ss  %s\n" "$base" "$status" "$dur" "$reason" | tee -a "$RUN/summary.txt"
done
echo "----------------------------------------------------------------" >> "$RUN/summary.txt"
echo "Fitur (01-14) : Lulus $PASS  Gagal $FAIL" | tee -a "$RUN/summary.txt"
echo "Regresi bug   : Masih BUG $BUGS  Sudah FIXED $FIXED" | tee -a "$RUN/summary.txt"
echo "Hasil: $RUN"
[ "$FAIL" -eq 0 ]
