import 'dart:convert';

import '../../../core/database/tables/users.dart';
import 'permission.dart';

/// Menyelesaikan **peran → himpunan permission efektif** (spec §13, 02).
///
/// Aturan inti (murni, tanpa I/O → mudah di-unit-test):
/// - `owner` → **semua** permission (selalu penuh, tak bisa dikurangi).
/// - `admin`/`cashier`/`staff` → default peran ([roleDefaults]).
/// - `custom` → tepat dari JSON array nama permission (mengabaikan nama asing).
class PermissionResolver {
  const PermissionResolver._();

  /// Default izin per peran (owner selalu penuh, di luar peta ini).
  /// Bisa disesuaikan bila kebijakan toko berubah.
  static const Map<AppRole, Set<Permission>> roleDefaults = {
    // Admin: nyaris penuh, tanpa kelola karyawan, hapus bill tutup, & setting toko.
    AppRole.admin: {
      Permission.dashboardAccess,
      Permission.productManagement,
      Permission.addProduct,
      Permission.variantManagement,
      Permission.customerManagement,
      Permission.transactionList,
      Permission.transactionUpdate,
      Permission.transactionExport,
      Permission.orderManagement,
      Permission.orderList,
      Permission.creditList,
      Permission.walletView,
      Permission.walletManagement,
      Permission.employeeSummary,
      Permission.notificationSetting,
      Permission.recycleBin,
    },
    // Cashier: operasi kasir + pelanggan + hutang; tanpa produk/laporan/setting.
    AppRole.cashier: {
      Permission.dashboardAccess,
      Permission.transactionList,
      Permission.customerManagement,
      Permission.creditList,
      Permission.orderList,
    },
    // Staff: pengurus stok/gudang; tanpa kasir & laporan.
    AppRole.staff: {
      Permission.dashboardAccess,
      Permission.productManagement,
      Permission.addProduct,
      Permission.variantManagement,
      Permission.recycleBin,
    },
  };

  /// Himpunan seluruh permission (dipakai untuk owner).
  static Set<Permission> get all => Permission.values.toSet();

  /// Himpunan permission efektif untuk [role] dengan [customJson] (dipakai
  /// hanya bila `role == custom`). Selalu mengembalikan set baru (tak dibagikan).
  static Set<Permission> resolve(AppRole role, [String? customJson]) {
    switch (role) {
      case AppRole.owner:
        return all;
      case AppRole.custom:
        return decodePermissions(customJson);
      case AppRole.admin:
      case AppRole.cashier:
      case AppRole.staff:
        return {...?roleDefaults[role]};
    }
  }

  /// Parse JSON array nama permission → set (nama asing/typo diabaikan diam).
  static Set<Permission> decodePermissions(String? json) {
    if (json == null || json.trim().isEmpty) return <Permission>{};
    final byName = {for (final p in Permission.values) p.name: p};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return <Permission>{};
      return {
        for (final e in decoded)
          if (e is String && byName.containsKey(e)) byName[e]!,
      };
    } catch (_) {
      return <Permission>{};
    }
  }

  /// Encode set permission → JSON array nama (disimpan di `users.permissions`).
  static String encodePermissions(Set<Permission> permissions) =>
      jsonEncode(permissions.map((p) => p.name).toList()..sort());
}
