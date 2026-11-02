# Laporan Testability — Fondasi Automation Testing (Android)

- **Tanggal:** 2026-09-01
- **Agen:** QA — Senior Mobile Automation Test Engineer (Android)
- **Lingkup:** Verifikasi prasyarat testability (spec/06 bagian E) + pembangunan
  fondasi harness/robot/smoke. **Tidak ada kode fitur produksi yang diubah.**
- **Acuan kebenaran:** `spec/06-agen-qa-automation.md` (E, F), `spec/03-business-rules.md`.

---

## Ringkasan Verdict

| Prasyarat E | Status | Catatan |
|---|---|---|
| #1 DI hardware via override Riverpod | ⚠️ **Sebagian** | Printer & kontak ✓; **scanner ✗**; biometrik ✗ (lihat G2, G3) |
| #2 Drift mode in-memory | ✅ Terpenuhi | `AppDatabase(NativeDatabase.memory())` + `appDatabaseProvider` overridable |
| #3 Keys/Semantics widget kunci | ❌ **Tidak terpenuhi** | POS & layar gerbang tanpa key (G1) |
| #4 Hardware tak dipanggil langsung di UI | ⚠️ **Sebagian** | Dilanggar scanner (G2) & biometrik (G3) |

**Fondasi tetap dibangun & hijau** dengan siasat text/label-finder (lihat README
`test/`). Namun temuan di bawah **harus** ditangani agen developer agar cakupan
E2E Fase 1–2 (scan barcode, kasir) bisa deterministik & tahan-perubahan UI.

---

## Temuan

### G1 — Widget kunci tanpa Keys/Semantics · Severity: **High**
**Prasyarat:** E#3.
**Bukti:** `grep -rn "ValueKey\|Key(" lib/features/pos/presentation` → **0 hasil**.
Layar gerbang (`onboarding_screen`, `set_pin_screen`, `pin_login_screen`) juga
tanpa `Key`/`Semantics` pada field & tombol.
**Dampak:** Robot E2E terpaksa mengandalkan **teks label** (mis. `find.text('Buat & Masuk')`)
dan urutan field. Rapuh: ganti copy/urutan → test putus; ambiguitas saat 2 layar
termount selama transisi (sudah terbukti — lihat catatan di bawah).
**Ekspektasi (spec/06 E#3):** beri `Key`/`Semantics` pada widget kunci —
minimal: tombol **Bayar**, field **qty**, item **keranjang** (POS); dan disarankan
field PIN/nama + tombol utama di layar gerbang.
**Rekomendasi konkret:** `ValueKey('pay_button')`, `ValueKey('cart_qty_field')`,
`ValueKey('cart_item_<id>')`, `ValueKey('onboarding_name_field')`,
`ValueKey('setpin_pin_field')`, `ValueKey('setpin_confirm_field')`,
`ValueKey('pinlogin_pin_field')`, `ValueKey('primary_button')`.

### G2 — Scanner kamera dipanggil langsung di UI (tanpa provider) · Severity: **High**
**Prasyarat:** E#1 & E#4.
**Bukti:** `lib/features/products/presentation/barcode_scanner_screen.dart` meng-
instansiasi `MobileScannerController` **langsung di `State`**, dibuka via
`MaterialPageRoute` di `product_form_screen.dart:99` — **bukan** lewat provider
yang bisa di-`override`.
**Dampak:** Alur "scan barcode → isi field" **tak bisa diuji headless** (butuh
kamera fisik). Melanggar E#4 ("hardware tak dipanggil langsung di UI").
**Ekspektasi:** bungkus scanner di balik interface + provider (mis.
`barcodeScannerProvider`) yang mengembalikan kode, agar fake bisa menginjeksi
kode uji tanpa kamera. UI memanggil provider, bukan `MobileScannerController`
langsung.

### G3 — Biometrik dipanggil langsung di UI · Severity: **Medium**
**Prasyarat:** E#1 & E#4.
**Bukti:** `lib/features/auth/presentation/pin_login_screen.dart:68`
`LocalAuthentication().authenticate(...)` dipanggil inline di widget.
**Dampak:** Aksi tap biometrik tak bisa di-fake. **Mitigasi tersedia:**
`biometricAvailableProvider` bisa di-override → harness memaksa tombol biometrik
**mati** sehingga jalur PIN teruji penuh. Karena itu Medium, bukan High.
**Ekspektasi:** pindahkan `authenticate()` ke service di balik provider agar jalur
login biometrik pun bisa diuji.

### G4 — Service hardware = kelas konkret (bukan interface) · Severity: **Low**
**Bukti:** `ReceiptThermalPrinter` & `ContactImportService` kelas konkret, tapi
**sudah** di provider (`receiptThermalPrinterProvider`,
`contactImportServiceProvider`) dan metodenya instance-level.
**Dampak:** **Tidak memblokir** — di-fake via subclass (lihat
`test/helpers/fakes.dart`). Saran (opsional): ekstrak interface abstrak untuk
seam yang lebih bersih.

---

## Catatan tambahan (bukan blocker)
- **Injeksi waktu (clock):** spec/06 §F & §14 meminta waktu di-inject. Saat ini
  timestamp memakai `DateTimeUtils.nowEpochMs()` global. Untuk uji invoice harian
  (§8) & laporan "hari ini" (§14) yang stabil, disarankan seam clock yang bisa
  di-override. Harness `formatRupiah`/matcher sudah disiapkan; clock menyusul.
- **`spec/bug-report-template.md` tidak ada**, padahal dirujuk di spec/06 §J.3.
  Laporan ini memakai struktur setara (verdict + temuan + severity + ekspektasi).

## Bukti yang sudah hijau
- `flutter test test/smoke/app_boot_smoke_test.dart` → **2/2 lulus**, konsisten
  **3× jalan** (tidak flaky).
- `flutter test test/helpers/money_matchers_test.dart` → **3/3 lulus**.
