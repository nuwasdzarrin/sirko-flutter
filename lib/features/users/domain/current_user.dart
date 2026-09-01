import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import 'permission.dart';
import 'permission_resolver.dart';

/// Pengguna yang sedang login pada sesi ini + **permission efektif** yang sudah
/// diselesaikan (owner ⇒ semua). Dipakai untuk gating UI/aksi (§13).
class CurrentUser {
  final String id;
  final String name;
  final String username;
  final AppRole role;

  /// Permission efektif (sudah diturunkan dari peran / owner-penuh / custom).
  final Set<Permission> permissions;

  const CurrentUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.permissions,
  });

  /// Rakit dari baris Drift [User] (menyelesaikan permission via resolver).
  factory CurrentUser.fromRow(User row) => CurrentUser(
        id: row.id,
        name: row.name,
        username: row.username,
        role: row.role,
        permissions: PermissionResolver.resolve(row.role, row.permissions),
      );

  bool get isOwner => role == AppRole.owner;

  /// Punya izin [p]? Owner selalu true (permission-nya sudah berisi semua).
  bool can(Permission p) => permissions.contains(p);
}
