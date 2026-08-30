# Sirko

**Sirko** (akronim *"Kasir Toko"*) — aplikasi POS/kasir digital untuk **ritel**: toko
kelontong, toko grosir, hingga supermarket. Dibangun dengan Flutter, **local-first**
(SQLite via Drift), dan Riverpod. Bukan untuk F&B.

- Application ID: `com.sirko.app`
- Platform: Android & iOS
- Prinsip non-negosiasi: uang = **integer rupiah**, primary key **UUID**, **soft delete**,
  waktu **epoch ms UTC**, jalan penuh **offline**.

## Stack
| Kebutuhan | Package |
|---|---|
| State management | `flutter_riverpod` + `riverpod_annotation`/`riverpod_generator` (v3, code-gen) |
| Database lokal | `drift` + `drift_flutter` + `sqlite3_flutter_libs` |
| Navigasi | `go_router` |
| Model | `freezed` + `json_serializable` |
| Auth lokal | `local_auth` + `flutter_secure_storage` (PIN di-hash PBKDF2) |

## Struktur
```
lib/
├── app/        # MaterialApp, router+guard, theme, session
├── core/       # money, database (+StandardColumns), utils, errors, widgets
└── features/   # onboarding, auth, shell (+fitur per fase berikutnya)
```
Aturan dependensi: `presentation → application → domain ← data`. Presentation/application
tidak menyentuh Drift langsung — selalu lewat repository.

## Menjalankan
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regen kode saat skema berubah
flutter run
flutter test
```

## Status
**Fase 0 (Fondasi)** selesai: setup proyek, Money + formatter, Drift kosong + kolom standar,
tema M3 light/dark + lokal `id_ID`, shell navigasi (drawer 6 menu), onboarding toko, dan
login PIN lokal (opsi biometrik). Roadmap fase berikutnya ada di `spec/04-roadmap-phases.md`.
