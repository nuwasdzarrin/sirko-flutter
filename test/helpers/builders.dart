import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/features/customers/data/customer_repository.dart';
import 'package:sirko/features/onboarding/data/business_repository.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/users/data/user_repository.dart';

/// Builder data uji (spec/06 §D "Test fixtures/builders").
///
/// Seluruh builder memakai **repository produksi**, bukan companion mentah,
/// agar tetap valid saat skema berevolusi (satu sumber kebenaran dengan app).

/// Buat 1 toko. Wajib ada sebelum login/kasir (router redirect ke onboarding
/// bila belum ada toko).
Future<void> seedBusiness(
  AppDatabase db, {
  String name = 'Toko Uji',
  String businessType = 'Toko Kelontong',
}) {
  return BusinessRepository(db)
      .createBusiness(name: name, businessType: businessType);
}

/// Buat 1 user owner dengan [pin]. Kembalikan id user.
/// Owner punya seluruh permission (§13) — cocok untuk skenario yang butuh akses
/// penuh tanpa mengurus gating.
Future<String> seedOwner(
  AppDatabase db, {
  String name = 'Pemilik',
  String username = 'owner',
  String pin = '123456',
}) {
  return UserRepository(db).create(
    name: name,
    username: username,
    pin: pin,
    role: AppRole.owner,
  );
}

/// Buat user non-owner (mis. `cashier`) untuk uji RBAC (Fase 6).
Future<String> seedUser(
  AppDatabase db, {
  required String name,
  required String username,
  required AppRole role,
  String pin = '123456',
}) {
  return UserRepository(db)
      .create(name: name, username: username, pin: pin, role: role);
}

/// Produk uji. Default: harga jual Rp10.000, stok 100. Kembalikan id.
Future<String> buildProduct(
  AppDatabase db, {
  String name = 'Produk Uji',
  String? barcode,
  int sellingPrice = 10000,
  int costPrice = 7000,
  int stock = 100,
  int? minStock,
  int? expiryDate,
  bool hasVariants = false,
}) {
  return ProductRepository(db).create(
    name: name,
    barcode: barcode,
    sellingPrice: sellingPrice,
    costPrice: costPrice,
    stock: stock,
    minStock: minStock,
    expiryDate: expiryDate,
    hasVariants: hasVariants,
  );
}

/// Pelanggan uji (dipakai transaksi kredit/hutang, Fase 4). Kembalikan id.
Future<String> buildCustomer(
  AppDatabase db, {
  String name = 'Pelanggan Uji',
  String? phone,
  String? address,
}) {
  return CustomerRepository(db)
      .create(name: name, phone: phone, address: address);
}
