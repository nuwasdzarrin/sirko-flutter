#!/usr/bin/env bash
# Sebelum TC-16b: admin (backend LOKAL) mengonfirmasi tagihan Paket Juragan
# dari TC-16a. Pakai: <RUN_ID>
set -eu
cd /c/project/sirko/sirko-hono
export PATH="/c/dev/node-22:$PATH"
node --env-file=.env --import tsx ../scripts/admin-lokal.mts confirm-juragan-of "e2e$1@toko.id"
