#!/usr/bin/env bash
# Sebelum TC-18b: admin (backend LOKAL) mengonfirmasi top-up Poin dari TC-18a
# dan memastikan produk Token PLN 20.000 ada. Pakai: <RUN_ID>
set -eu
cd /c/project/sirko/sirko-hono
export PATH="/c/dev/node-22:$PATH"
H="node --env-file=.env --import tsx ../scripts/admin-lokal.mts"
$H pln-product 20000 20500
$H confirm-topups-of "e2e$1@toko.id"
