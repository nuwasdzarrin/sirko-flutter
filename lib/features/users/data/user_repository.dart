import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../auth/data/pin_hasher.dart';
import '../domain/permission.dart';
import '../domain/permission_resolver.dart';

/// Akses tabel `users` (CRUD karyawan + verifikasi PIN, spec §13).
///
/// PIN di-hash via [PinHasher] (`saltB64:hashB64`) — tak pernah plain. Owner
/// tak boleh dihapus/di-nonaktif bila **satu-satunya** pemegang `administrator`
/// (§13). UI/application tak menyentuh Drift langsung — selalu lewat repo ini.
class UserRepository {
  final AppDatabase _db;
  const UserRepository(this._db);

  static const _uuid = Uuid();

  /// Daftar user aktif (non-terhapus) — reaktif, urut nama.
  Stream<List<User>> watchUsers({bool includeInactive = true}) {
    final q = _db.select(_db.users)..where((t) => t.deletedAt.isNull());
    if (!includeInactive) q.where((t) => t.isActive.equals(true));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch();
  }

  /// User aktif untuk layar login (isActive & non-terhapus).
  Stream<List<User>> watchLoginableUsers() {
    return (_db.select(_db.users)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<User?> getById(String id) => (_db.select(_db.users)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  Future<int> countActive() async {
    final rows = await (_db.select(_db.users)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true)))
        .get();
    return rows.length;
  }

  Future<bool> hasAnyActiveUser() async => (await countActive()) > 0;

  /// Verifikasi PIN untuk user tertentu. Return user bila cocok & aktif.
  Future<User?> verifyPin(String userId, String pin) async {
    final user = await getById(userId);
    if (user == null || user.deletedAt != null || !user.isActive) return null;
    return PinHasher.verify(pin, user.pinHash) ? user : null;
  }

  /// Buat user baru. [permissions] dipakai hanya bila `role == custom`.
  Future<String> create({
    required String name,
    required String username,
    required String pin,
    required AppRole role,
    Set<Permission> permissions = const {},
  }) async {
    await _ensureUsernameFree(username, null);
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            name: name,
            username: username,
            pinHash: PinHasher.hash(pin),
            role: role,
            permissions: Value(role == AppRole.custom
                ? PermissionResolver.encodePermissions(permissions)
                : null),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Update data user (tanpa PIN). Ganti PIN lewat [changePin].
  Future<void> update(
    String id, {
    required String name,
    required String username,
    required AppRole role,
    Set<Permission> permissions = const {},
    required bool isActive,
  }) async {
    await _ensureUsernameFree(username, id);
    // Guard §13: owner terakhir dgn administrator tak boleh dinonaktifkan.
    if (!isActive) await _guardLastAdministrator(id);
    await (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
      UsersCompanion(
        name: Value(name),
        username: Value(username),
        role: Value(role),
        permissions: Value(role == AppRole.custom
            ? PermissionResolver.encodePermissions(permissions)
            : null),
        isActive: Value(isActive),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> changePin(String id, String newPin) {
    return (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
      UsersCompanion(
        pinHash: Value(PinHasher.hash(newPin)),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete user (§12). Ditolak untuk owner administrator terakhir (§13).
  Future<void> softDelete(String id) async {
    await _guardLastAdministrator(id);
    final now = DateTimeUtils.nowEpochMs();
    await (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
      UsersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Seed user **owner** dari PIN legacy (Fase 0) bila belum ada user sama sekali
  /// (§13). Menjaga PIN pemilik lama tetap berfungsi tanpa reset. Idempoten:
  /// tak melakukan apa pun bila sudah ada user.
  ///
  /// [legacyCredential] = `saltB64:hashB64` dari `PinRepository`.
  Future<void> seedOwnerFromLegacy({
    required String? legacyCredential,
    String ownerName = 'Pemilik',
  }) async {
    if (await hasAnyActiveUser()) return;
    if (legacyCredential == null) return;
    final now = DateTimeUtils.nowEpochMs();
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: _uuid.v4(),
            name: ownerName,
            username: 'owner',
            pinHash: legacyCredential,
            role: AppRole.owner,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // --- internal ---

  Future<void> _ensureUsernameFree(String username, String? exceptId) async {
    final rows = await (_db.select(_db.users)
          ..where((t) =>
              t.username.equals(username) & t.deletedAt.isNull()))
        .get();
    final clash = rows.where((u) => u.id != exceptId);
    if (clash.isNotEmpty) {
      throw AppException('Username "$username" sudah dipakai.');
    }
  }

  /// Cegah menghapus/menonaktifkan **satu-satunya** user administrator aktif
  /// (§13). Owner memiliki permission `administrator` secara implisit.
  Future<void> _guardLastAdministrator(String id) async {
    final target = await getById(id);
    if (target == null) return;
    final targetIsAdmin = CurrentUserPermissions.hasAdministrator(target);
    if (!targetIsAdmin) return;

    final actives = await (_db.select(_db.users)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true)))
        .get();
    final otherAdmins = actives.where(
        (u) => u.id != id && CurrentUserPermissions.hasAdministrator(u));
    if (otherAdmins.isEmpty) {
      throw const AppException(
          'Tak bisa menghapus/menonaktifkan administrator terakhir.');
    }
  }
}

/// Bantuan kecil: apakah baris user memegang permission `administrator`
/// (owner selalu ya). Diletakkan di sini agar guard §13 tetap murni & teruji.
class CurrentUserPermissions {
  const CurrentUserPermissions._();

  static bool hasAdministrator(User u) {
    if (u.role == AppRole.owner) return true;
    return PermissionResolver.resolve(u.role, u.permissions)
        .contains(Permission.administrator);
  }
}
