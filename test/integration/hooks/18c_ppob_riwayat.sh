#!/usr/bin/env bash
# Sebelum TC-18c: admin (backend LOKAL) mengisi token untuk order PLN yang
# menunggu dari TC-18b. Pakai: <RUN_ID>
set -eu
cd /c/project/sirko/sirko-hono
export PATH="/c/dev/node-22:$PATH"
node --env-file=.env --import tsx ../scripts/admin-lokal.mts \
  fulfill-waiting-of "e2e$1@toko.id" 12345678901234567890
