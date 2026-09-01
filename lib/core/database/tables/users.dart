import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Peran pengguna (spec 02 `users.role`, §13). Owner **selalu** penuh.
/// `custom` → izin dibaca dari kolom JSON `permissions`.
/// Tak ada reserved word → disimpan apa adanya via `textEnum` (`.name`).
enum AppRole { owner, admin, cashier, staff, custom }

/// Pengguna: pemilik & karyawan (spec 02-data-model, Fase 6).
///
/// PIN tak pernah disimpan plain: [pinHash] menyimpan kredensial ter-hash
/// PBKDF2 berformat `saltB64:hashB64` (lihat `PinHasher`). Owner selalu punya
/// semua permission; peran lain memakai default peran, `custom` memakai
/// [permissions] (JSON array nama permission).
class Users extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Nama login unik (dipakai memilih user saat login).
  TextColumn get username => text().withLength(min: 1, max: 60)();

  /// Kredensial PIN ter-hash (`saltB64:hashB64`, PBKDF2-HMAC-SHA256).
  TextColumn get pinHash => text()();

  TextColumn get role => textEnum<AppRole>()();

  /// Daftar permission untuk role `custom` (JSON array of names). Null/`[]`
  /// untuk role non-custom (izin diturunkan dari peran).
  TextColumn get permissions => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
