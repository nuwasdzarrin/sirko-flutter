import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/features/users/domain/permission.dart';
import 'package:sirko/features/users/domain/permission_resolver.dart';

/// Uji evaluasi RBAC (spec §13): owner penuh, default peran, custom izin/tolak.
void main() {
  group('resolve peran', () {
    test('owner → SEMUA permission (selalu penuh)', () {
      final perms = PermissionResolver.resolve(AppRole.owner);
      expect(perms, Permission.values.toSet());
      // Termasuk izin paling sensitif.
      expect(perms.contains(Permission.administrator), isTrue);
      expect(perms.contains(Permission.deleteClosedBill), isTrue);
      expect(perms.contains(Permission.settingCompany), isTrue);
    });

    test('cashier → izin operasi kasir, TOLAK menu terlarang', () {
      final perms = PermissionResolver.resolve(AppRole.cashier);
      // Diizinkan.
      expect(perms.contains(Permission.transactionList), isTrue);
      expect(perms.contains(Permission.customerManagement), isTrue);
      expect(perms.contains(Permission.creditList), isTrue);
      // Ditolak.
      expect(perms.contains(Permission.productManagement), isFalse);
      expect(perms.contains(Permission.settingCompany), isFalse);
      expect(perms.contains(Permission.userService), isFalse);
      expect(perms.contains(Permission.deleteClosedBill), isFalse);
      expect(perms.contains(Permission.administrator), isFalse);
    });

    test('admin → hampir penuh, tanpa kelola user/hapus bill/setting toko', () {
      final perms = PermissionResolver.resolve(AppRole.admin);
      expect(perms.contains(Permission.productManagement), isTrue);
      expect(perms.contains(Permission.transactionExport), isTrue);
      expect(perms.contains(Permission.employeeSummary), isTrue);
      // Batasan admin.
      expect(perms.contains(Permission.userService), isFalse);
      expect(perms.contains(Permission.addUser), isFalse);
      expect(perms.contains(Permission.administrator), isFalse);
      expect(perms.contains(Permission.deleteClosedBill), isFalse);
      expect(perms.contains(Permission.settingCompany), isFalse);
    });

    test('staff → hanya produk/stok & dashboard', () {
      final perms = PermissionResolver.resolve(AppRole.staff);
      expect(perms.contains(Permission.productManagement), isTrue);
      expect(perms.contains(Permission.variantManagement), isTrue);
      // Tak bisa kasir/laporan.
      expect(perms.contains(Permission.transactionList), isFalse);
      expect(perms.contains(Permission.transactionExport), isFalse);
    });
  });

  group('custom (dari JSON)', () {
    test('mengambil tepat izin yang tercantum', () {
      final json = PermissionResolver.encodePermissions({
        Permission.transactionList,
        Permission.customerManagement,
      });
      final perms = PermissionResolver.resolve(AppRole.custom, json);
      expect(perms, {
        Permission.transactionList,
        Permission.customerManagement,
      });
      expect(perms.contains(Permission.productManagement), isFalse);
    });

    test('null/kosong → tak ada izin (tolak semua)', () {
      expect(PermissionResolver.resolve(AppRole.custom, null), isEmpty);
      expect(PermissionResolver.resolve(AppRole.custom, ''), isEmpty);
      expect(PermissionResolver.resolve(AppRole.custom, '[]'), isEmpty);
    });

    test('nama permission asing/typo diabaikan, JSON rusak → kosong', () {
      final perms = PermissionResolver.resolve(
          AppRole.custom, '["transactionList","tidakAda"]');
      expect(perms, {Permission.transactionList});
      expect(PermissionResolver.resolve(AppRole.custom, 'bukan json'), isEmpty);
    });

    test('encode → decode round-trip konsisten', () {
      final original = {
        Permission.dashboardAccess,
        Permission.walletView,
        Permission.recycleBin,
      };
      final json = PermissionResolver.encodePermissions(original);
      expect(PermissionResolver.decodePermissions(json), original);
    });
  });

  test('owner tak bisa dikurangi walau customJson diberikan', () {
    final perms =
        PermissionResolver.resolve(AppRole.owner, '["transactionList"]');
    expect(perms, Permission.values.toSet());
  });
}
