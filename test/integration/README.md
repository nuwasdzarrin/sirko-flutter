# Integration test E2E — Maestro (Android)

Suite black-box yang menjalankan **APK Sirko sungguhan** di emulator/HP lewat
[Maestro](https://maestro.mobile.dev), lengkap dengan **rekaman layar per flow**.
Melengkapi test host (`flutter test`) dan Patrol (`test/integration_test/`).

## Prasyarat (Windows)

| Komponen | Lokasi di mesin ini |
|---|---|
| Java 17+ | JBR Android Studio: `C:\Program Files\Android\Android Studio\jbr` (`JAVA_HOME` user) |
| Maestro CLI 2.12+ | `C:\maestro\bin` (sudah di PATH user) |
| adb | `%LOCALAPPDATA%\Android\Sdk\platform-tools` (sudah di PATH user) |
| Emulator / HP | `adb devices` harus menampilkan perangkat (default `emulator-5554`) |
| APK | `com.sirko.app` terpasang (release/debug sama saja) |

Ganti perangkat: `DEVICE=emulator-5556 bash test/integration/scripts/run_all.sh`.

## Menjalankan

```bash
# Git Bash, dari folder sirko/
bash test/integration/scripts/run_all.sh            # seluruh suite (01–14 + 90–98), ±60 menit
bash test/integration/scripts/run_all.sh 01 02 04   # sebagian (pola awalan nama file)
```
```powershell
# PowerShell / terminal VS Code, dari folder sirko/
.\test\integration\scripts\run_all.ps1
```

> ⚠️ **TC-01 menghapus data aplikasi** (`clearState`). Jalankan di emulator/HP uji, bukan HP toko.
> Flow saling bergantung data (urut 01 → 14); menjalankan satu flow di tengah butuh state dari flow sebelumnya.

### Hasil run → `record/<YYYY-MM-DD_HHMMSS>/` (di-*gitignore*)

```
summary.txt      ringkasan LULUS/GAGAL/BUG + durasi + alasan gagal
videos/          1 video .mp4 per flow (rekaman layar penuh)
screenshots/     screenshot checkpoint (nama = <flow>_<langkah>.png); GAGAL_*.png bila gagal
junit/           laporan JUnit XML per flow (untuk CI)
artifacts/       log Maestro + hierarki UI + logcat per flow (bahan debug)
```

Status flow regresi bug (90–98): **BUG** = bug masih ada (assert perilaku seharusnya gagal),
**FIXED** = bug sudah diperbaiki. Flow 90 (BUG-01, race intermiten) memakai **TAK-TERPICU**
bila lulus — belum tentu sudah diperbaiki.

## Katalog test case

| ID | Flow | Cakupan utama |
|---|---|---|
| TC-01 | `01_onboarding_pemilik` | Instal bersih, validasi nama toko & PIN (min 6, harus sama), buat pemilik, Beranda Rp0, versi app |
| TC-02 | `02_login_logout` | Sesi tak dipersist, PIN salah ditolak, logout → layar PIN |
| TC-03 | `03_produk_master` | Kategori & satuan, 3 produk, validasi nama, cari nama/barcode, edit harga, filter kategori, hapus → Recycle Bin → restore |
| TC-04 | `04_kasir_tunai` | Keranjang, bayar tunai + kembalian, struk PDF, riwayat & detail, stok berkurang, void → stok kembali, blokir stok kurang |
| TC-05 | `05_kasir_diskon_tunda_split` | Diskon item %, diskon transaksi Rp, Tunda & Lanjutkan (diskon ikut), split Tunai+QRIS, keranjang keepAlive |
| TC-06 | `06_pelanggan_kasbon_cicilan` | Pelanggan baru, Kas Bon dengan DP, 3 cicilan, bayar cicilan, bayar hutang, Daftar Kas Bon |
| TC-07 | `07_kas_wallet` | Kas default dari penjualan, wallet baru, kas masuk/keluar, tolak overdraw, transfer atomik, laporan arus kas |
| TC-08 | `08_supplier_pembelian` | Supplier, kulakan 2 barang + diskon nota, bayar sebagian dari bank, stok naik, harga modal last-cost, hutang supplier |
| TC-09 | `09_opname_stok` | Opname + finalisasi (rugi), sesi FINAL terkunci, penyesuaian manual, stok menipis, arus stok (audit) |
| TC-10 | `10_karyawan_rbac_shift` | Wajib shift, karyawan Kasir, RBAC menu, blokir transaksi tanpa shift, buka/tutup shift (selisih kas), ringkasan karyawan |
| TC-11 | `11_grosir_varian` | Tier grosir otomatis (qty 9 vs 10), produk bervarian + 2 varian |
| TC-12 | `12_laporan_ekspor` | Beranda & 5 tab laporan, ekspor PDF (share → print preview), ekspor XLSX |
| TC-13 | `13_katalog_umum` | Katalog seed offline (cari nama/barcode), tab Online & Usulkan butuh cloud, validasi login cloud |
| TC-14 | `14_navigasi_menu` | 5 tab, mode fokus Kasir, 10 menu Lainnya, 8 pintasan Beranda |
| TC-15 | `15_sync_cloud` | Sinkronisasi cloud: daftar akun dari HP berisi data → push → "Tersinkron"; hapus data app (HP baru) → **Pulihkan dari Cloud** → PIN pemilik & data kembali. **Butuh backend uji** (lihat bawah) |
| BUG-01…09 | `90`–`98` | Regresi bug terkonfirmasi — lihat `test/qa-reports/maestro-e2e-2026-10-31.md` |

Data uji: toko **Toko Maestro**, pemilik **Budi Pemilik / PIN 123456**, kasir **Rina Kasir / PIN 111111**.

### TC-15 (sinkronisasi) — backend uji lokal, JANGAN produksi
TC-15 membuat akun cloud baru. Jalankan terhadap backend lokal + Postgres uji:
```bash
# 1) backend lokal (sirko-backend) — env eksplisit, BUKAN `npm run dev` (.env = PROD)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/sirko_test JWT_SECRET=<min 32 char> JWT_REFRESH_SECRET=<min 32 char> PORT=3000 node --import tsx src/dev-server.ts
# 2) APK debug yang menunjuk backend lokal (HTTP polos hanya diizinkan di debug)
flutter build apk --debug --target-platform android-x64   --dart-define=SIRKO_API_BASE=http://10.0.2.2:3000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# 3) jalankan
bash test/integration/scripts/run_all.sh 01 02 03 04 15
```
Uji kontrak sync tanpa emulator (backend lokal sama):
`flutter test --dart-define=SIRKO_API_BASE=http://localhost:3000 test/sync/sync_contract_test.dart`

## Struktur

```
test/integration/
├── flows/       # 1 file = 1 test case (urut nama). Masing-masing startRecording/stopRecording.
├── subflows/    # langkah bersama: login_pemilik, isi_field, menu_tile, buka_menu_lainnya, …
├── scripts/     # run_all.sh (runner+rekam), try.sh (debug 1 flow), hier.sh (dump UI), env.sh
└── record/      # hasil run (gitignored)
```

## Konvensi & jebakan Maestro × Flutter (sudah dibuktikan di suite ini)

- **Selector = teks semantics Flutter.** Teks multi-baris (mis. kartu `Omzet\nRp0\n0 transaksi`)
  dicocokkan dengan spasi: `"Omzet Rp0 0 transaksi"`. Selector adalah regex *full match*;
  escape `( ) . +` → `\\(` di YAML double-quote.
- **Field teks:** selalu lewat `subflows/isi_field.yaml` (tap → tunggu animasi → `eraseText` → ketik).
  `inputText` langsung ke field autofocus menggandakan huruf pertama (`TokToko`, `PPak Andi`).
  Field ber-label tetap punya `hintText` walau terisi → bisa ditarget dengan label; field dengan
  *hint* biasa (kotak cari) kehilangan hint saat terisi → kosongkan via `kosongkan_field.yaml`.
- **`hideKeyboard` tanpa keyboard terbuka = tombol Back** → bisa menutup sheet/keluar app.
- **Ikon tanpa teks** (tooltip Flutter tak terbaca Maestro) diberi id semantics lewat widget
  `TestId` (`lib/core/widgets/test_id.dart`, sejak build 11) → `tapOn: { id: "<id>" }`.
  Id yang ada: `kasir_scan`, `kasir_daftar_tunda`, `kasir_riwayat`, `kasir_ke_beranda`,
  `transaksi_batalkan`, `produk_stok_masuk`, `produk_peringatan_stok`, `produk_menu_inventory`,
  `produk_scan_barcode`, `produk_kelola_kategori`, `produk_kelola_satuan`, `karyawan_simpan`.
  Field nominal split payment berlabel `Nominal <metode>`; tombol qty keranjang `Tambah qty`/`Kurangi qty`.
  Tombol baru tanpa teks → bungkus `TestId` agar tetap bisa diotomasi.
- **Laporan** di-assert dengan periode **"7 hari"** (bukan "Hari ini") agar run yang melewati tengah malam tetap valid.
- **Runner** melakukan preflight: reset sisa driver Maestro + warm-up (≤4×), timeout start driver 120 s
  (`MAESTRO_DRIVER_STARTUP_TIMEOUT`), dan mengulang flow yang gagal **hanya** karena driver belum siap.
- **APK uji harus segar:** hapus `C:\fbuild\sirko` sebelum build (Gradle bisa memaketkan `app.so` lama).
- **Keyboard layar** wajib aktif (runner set `show_ime_with_hard_keyboard=1`); tanpa itu
  `hideKeyboard` = Back. `isi_field` memverifikasi hasil ketikan (Gboard kadang menyisipkan spasi ganda).
- **Menu ⋮ pada tile daftar**: `tapOn: { childOf: "<teks tile>", index: 1 }` (`subflows/menu_tile.yaml`).
- **Nama flow** (`name:`) dipakai sebagai nama folder output → tanpa `:` (Windows).
- Debug cepat: `bash scripts/try.sh flows/<flow>.yaml` lalu `bash scripts/hier.sh` untuk melihat
  teks/label yang terlihat Maestro di layar saat ini.
