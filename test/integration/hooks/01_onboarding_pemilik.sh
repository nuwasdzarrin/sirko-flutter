#!/usr/bin/env bash
# Sebelum TC-01: kosongkan pembatas login/daftar backend LOKAL (auth_throttle).
# Run E2E berulang dari satu IP (emulator → 127.0.0.1) cepat kena 429.
set -eu
cd /c/project/sirko/sirko-hono
export PATH="/c/dev/node-22:$PATH"
node --env-file=.env --import tsx ../scripts/admin-lokal.mts clear-throttle
