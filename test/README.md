# Automation Testing — Sirko (Android)

Fondasi test mengikuti `spec/06-agen-qa-automation.md` bagian F. Uang selalu
integer rupiah; semua fitur offline. **Kode fitur produksi tidak diubah oleh
agen QA** — bug/testability dilaporkan ke `qa-reports/`.

## Struktur

```
test/                                  # widget & unit-level (host, `flutter test`)
├── helpers/
│   ├── pump_app.dart                  # pumpApp() / pumpFullApp() + override standar + pumpUntil*
│   ├── test_database.dart             # createMemoryDb() — Drift NativeDatabase.memory()
│   ├── fakes.dart                     # FakeReceiptThermalPrinter / FakeContactImportService / FakePinRepository
│   ├── builders.dart                  # seedBusiness/seedOwner/seedUser/buildProduct/buildCustomer
│   ├── money_matchers.dart            # formatRupiah / isRupiah / findRupiah
│   └── money_matchers_test.dart       # uji-mandiri matcher
├── smoke/
│   └── app_boot_smoke_test.dart       # SMOKE host: buka app → set toko → PIN → dashboard
└── <fitur>/…                          # test host per fitur (sudah ada dari agen dev)

integration_test/                      # E2E native (Patrol, `patrol test`)
├── helpers/robots/                    # Pola Robot/Page-Object
│   ├── robot.dart                     # basis: pumpUntil*, tapButtonByLabel, fieldByLabel
│   ├── onboarding_robot.dart
│   ├── pin_robot.dart                 # SetPin (buatOwner) & PinLogin (loginDenganPin)
│   └── dashboard_robot.dart
└── flows/
    └── onboarding_login_flow_test.dart # SMOKE Patrol (alur & robot sama dgn smoke host)
```

## Menjalankan

### Widget / host (cepat, tanpa emulator)
```bash
flutter test                                   # semua test host
flutter test test/smoke/app_boot_smoke_test.dart
```

### E2E native — Patrol (butuh emulator Android)
Prasyarat: `dart pub global activate patrol_cli`, lalu AVD menyala
(`adb devices` harus melihat perangkat).

```bash
# API terbaru (target-SDK) — mis. AVD "Pixel_7_API_35"
patrol test -t integration_test/flows/onboarding_login_flow_test.dart

# min-SDK — AVD "Nexus_5_API_25" (minSdk proyek = 23, jadi API 25 valid)
patrol test -t integration_test/flows/onboarding_login_flow_test.dart
```
Jalankan bergantian pada **kedua AVD** (API 25 & terbaru) — DoD spec/06 §H.

## Konvensi (spec/06 §F)
- **Deterministik:** tanpa `sleep` acak; **jangan** `pumpAndSettle` (layar memakai
  `CircularProgressIndicator` tak-berujung → menggantung). Pakai loop `pumpUntil*`.
  Test host membungkus alur dalam `tester.runAsync` agar timer stream Drift berdetak.
- **Isolasi:** tiap test mulai dari `createMemoryDb()` bersih + `close()` di tearDown.
- **Robot/Page-Object** untuk E2E; **AAA**; satu perilaku per test; nama deskriptif
  yang menyebut aturan.
- **Fakes hardware** di-inject via `defaultTestOverrides` (printer, kontak, PIN
  secure-storage, biometrik). Scanner kamera **belum** bisa di-fake — lihat
  `qa-reports/testability-foundation-2026-09-01.md` (G2).

## Status fondasi
Smoke host **hijau & tidak flaky** (3× jalan). Smoke Patrol siap dijalankan di
emulator. Gap testability G1–G4 tercatat di `qa-reports/`.
