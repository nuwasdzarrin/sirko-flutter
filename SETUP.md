# Setup Pengembangan — Multi-Mesin (macOS + Windows)

Repo ini dikerjakan dari **dua mesin** (MacBook & PC Windows kantor). Aturan di bawah
menjamin keduanya tak saling menimpa: **Git satu-satunya jalur sinkron**, **versi tool
dikunci**, dan **konfigurasi per-mesin tak pernah di-commit**.

## 1. Versi wajib (sama di semua mesin)

| Tool | Versi | Catatan |
|---|---|---|
| Flutter | **3.32.8** (Dart 3.8.1) | Dikunci di `.flutter-version`; `scripts/dev.*` menolak versi lain |
| JDK | **17** | Pakai JBR bawaan Android Studio (`flutter config --jdk-dir ...`) |
| Android SDK | platform **36**, build-tools 36.x | via SDK Manager / `sdkmanager "platforms;android-36"` |
| NDK | **27.0.12077973** | `sdkmanager "ndk;27.0.12077973"` |
| Gradle / AGP / Kotlin | 8.12 / 8.9.1 / 2.1.0 | Otomatis dari wrapper — jangan di-upgrade sepihak |

> Kenapa dikunci? Flutter versi lain mengubah `pubspec.lock` (paket yang dipin SDK:
> `leak_tracker`, `test`, `vector_math`, …) → tiap mesin menimpa lockfile mesin lain.
> **Bila `pubspec.lock` berubah padahal Anda tak menambah paket: jangan commit** —
> versi Flutter mesin itu salah.
>
> macOS < 14 tak bisa memakai Flutter terbaru (Dart VM butuh macOS 14), 3.32.8 aman.

Pasang Flutter terkunci **berdampingan** dengan Flutter lain (tak mengganggu proyek lain):

```bash
# macOS
git clone --depth 1 -b 3.32.8 https://github.com/flutter/flutter.git ~/development/flutter-3.32.8
```
```powershell
# Windows (path TANPA spasi)
git clone --depth 1 -b 3.32.8 https://github.com/flutter/flutter.git C:\dev\flutter-3.32.8
```

## 2. Lokasi proyek

- **Windows: wajib path tanpa spasi**, mis. `C:\dev\sirko-flutter`
  (bukan `C:\Users\WINDOWS 11\...`). Path berspasi memicu relokasi build ke
  `C:/fbuild/sirko` (workaround lama di `android/build.gradle.kts`).
- **Jangan** taruh proyek di OneDrive / Google Drive / iCloud / Dropbox — sinkronisasi
  `build/`, `.dart_tool/`, `.gradle/` antar-OS merusak Gradle. Hanya lewat Git.

## 3. Konfigurasi per-mesin — `env/local.json` (gitignored)

```bash
cp env/local.example.json env/local.json   # lalu sesuaikan
```

| Key | Fungsi | Bila kosong |
|---|---|---|
| `FLUTTER_BIN` | path Flutter 3.32.8 mesin ini | pakai `flutter` di PATH |
| `SIRKO_API_BASE` | URL backend sirko-hono | otomatis `http://<IP-LAN-mesin-ini>:47321` |

Contoh macOS: `{"FLUTTER_BIN": "/Users/<user>/development/flutter-3.32.8/bin/flutter"}`
Contoh Windows: `{"FLUTTER_BIN": "C:\\dev\\flutter-3.32.8\\bin\\flutter.bat"}`

Hal lain yang **memang beda per mesin** & tak di-commit: `android/local.properties`
(dibuat Flutter), `build/`, `.dart_tool/`, pairing ADB, `.env` backend (repo sirko-hono).

## 4. Menjalankan di HP (ADB Wi-Fi)

Sekali per mesin: HP → Opsi pengembang → **Wireless debugging** → *Pair device with
pairing code*, lalu `adb pair <IP:PORT-pairing> <KODE>`. Xiaomi/Redmi: aktifkan juga
**Instal via USB** (berlaku untuk ADB Wi-Fi).

```bash
scripts/dev.sh --connect 192.168.1.111:44105      # macOS — port dari layar Wireless debugging
scripts/dev.sh --build-only                       # build APK debug saja
```
```powershell
.\scripts\dev.ps1 -Connect 192.168.1.111:44105    # Windows
.\scripts\dev.ps1 -BuildOnly
```

Port Wireless debugging **berubah** tiap fitur itu dimatikan/nyala — ambil ulang dari layar HP.

Build debug terpasang sebagai **"Sirko Dev"** (`com.sirko.app.dev`) — berdampingan dengan
app rilis `com.sirko.app`, jadi data app rilis di HP tak tersentuh. Debug juga
mengizinkan HTTP (cleartext) ke backend LAN; rilis tetap HTTPS.

Backend (`sirko-hono`) berjalan di mesin yang sama pada port **47321**
(`PORT=47321` di `.env` sirko-hono). Firewall Windows: izinkan inbound TCP 47321
untuk jaringan *Private* agar HP bisa menjangkau.

## 5. Ritme kerja antar mesin

1. Mulai kerja: `git pull` → `flutter pub get` (via `scripts/dev.*` atau manual).
2. Selesai kerja: commit kecil → `git push`. Belum selesai? Commit ke branch `wip/...`
   atau `git stash` — jangan tinggalkan perubahan tak ter-commit saat pindah mesin.
3. Ubah tabel Drift / provider Riverpod → `dart run build_runner build --delete-conflicting-outputs`
   dengan Flutter 3.32.8, lalu **commit file `*.g.dart`**.
4. Line ending diatur `.gitattributes` (repo LF, `.ps1`/`.bat` CRLF). Di Windows set
   `git config core.autocrlf false` agar Git tak mengubah lagi.
