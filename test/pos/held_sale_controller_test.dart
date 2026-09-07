import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/pos/application/held_sale_providers.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/pos/domain/pos_enums.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/users/application/user_providers.dart';

import '../helpers/builders.dart';

/// R4 — HeldSaleController: tunda mengosongkan keranjang (stok tetap); lanjutkan
/// mengembalikan state keranjang; batalkan soft delete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // Hindari SessionController (secure storage) di test kontainer murni.
        currentUserProvider.overrideWith((ref) => null),
      ],
    );
    // Jaga provider autoDispose tetap hidup selama alur async.
    container.listen(cartControllerProvider, (_, __) {});
    container.listen(heldSaleControllerProvider, (_, __) {});
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('tunda: keranjang dikosongkan, held sale tersimpan, stok tetap',
      () async {
    await seedBusiness(db);
    final pid = await buildProduct(db, name: 'Kopi', sellingPrice: 5000, stock: 40);
    final product = await ProductRepository(db).getById(pid);

    final cart = container.read(cartControllerProvider.notifier);
    cart.addProduct(product!);
    cart.addProduct(product);
    cart.setTxDiscount(DiscountType.nominal, 1000);
    expect(container.read(cartControllerProvider).totalQty, 2);

    await container.read(heldSaleControllerProvider.notifier).hold(label: 'Bu Sri');

    // Keranjang kosong setelah tunda.
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
    // Held sale muncul di daftar tunda.
    expect(await container.read(heldSaleRepositoryProvider).watchCount().first, 1);
    // Stok tak berubah.
    final row =
        await (db.select(db.products)..where((t) => t.id.equals(pid))).getSingle();
    expect(row.stock, 40);
  });

  test('lanjutkan: mengembalikan item/qty/diskon/pelanggan, held terhapus',
      () async {
    await seedBusiness(db);
    final cid = await buildCustomer(db, name: 'Bu Sri');
    final pid = await buildProduct(db, name: 'Kopi', sellingPrice: 5000, stock: 40);
    final product = await ProductRepository(db).getById(pid);

    final cart = container.read(cartControllerProvider.notifier);
    cart.addProduct(product!);
    cart.addProduct(product); // qty 2
    cart.setLineDiscount(product.id, DiscountType.nominal, 500);
    cart.setTxDiscount(DiscountType.percent, 5);
    cart.setCustomer(cid);

    final id =
        await container.read(heldSaleControllerProvider.notifier).hold();
    expect(container.read(cartControllerProvider).isEmpty, isTrue);

    final ok =
        await container.read(heldSaleControllerProvider.notifier).resume(id);
    expect(ok, isTrue);

    final restored = container.read(cartControllerProvider);
    expect(restored.lines, hasLength(1));
    expect(restored.lines.single.qty, 2);
    expect(restored.lines.single.discountType, DiscountType.nominal);
    expect(restored.lines.single.discountValue, 500);
    expect(restored.txDiscountType, DiscountType.percent);
    expect(restored.txDiscountValue, 5);
    expect(restored.customerId, cid);
    // Re-fetch stok/modal terkini dari produk.
    expect(restored.lines.single.availableStock, 40);

    // Held sale hilang dari daftar tunda.
    expect(await container.read(heldSaleRepositoryProvider).watchCount().first, 0);
  });

  test('batalkan: soft delete tanpa mengembalikan ke keranjang', () async {
    await seedBusiness(db);
    final pid = await buildProduct(db, name: 'Kopi', stock: 40);
    final product = await ProductRepository(db).getById(pid);
    container.read(cartControllerProvider.notifier).addProduct(product!);

    final id =
        await container.read(heldSaleControllerProvider.notifier).hold();
    await container.read(heldSaleControllerProvider.notifier).cancel(id);

    expect(await container.read(heldSaleRepositoryProvider).watchCount().first, 0);
    // Keranjang tetap kosong (tak ada resume).
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });
}
