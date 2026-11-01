#!/usr/bin/env bash
# Jalankan satu flow (debug cepat) lalu ringkas hasilnya. Arg: path flow.
source "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../flows"
timeout 900 maestro --device "$DEVICE" test --test-output-dir="$TEMP/mout" "$(basename "$1")" 2>&1 \
  | grep -E "FAILED|Flow|Error|not found|Assertion is false|Parsing|Invalid|Exception" | grep -v "^\s*$" | head -12
