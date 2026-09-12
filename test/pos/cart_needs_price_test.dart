import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/products/data/product_repository.dart';

import '../helpers/builders.dart';

/// Guard §7: produk bertanda **perlu harga** tidak boleh masuk keranjang
/// (cegah jual Rp0); setelah harga diisi (>0), baru bisa ditambahkan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.listen(cartControllerProvider, (_, __) {});
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('produk perlu-harga ditolak; keranjang tetap kosong', () async {
    final pid = await buildProduct(db,
        name: 'Sprite', sellingPrice: 0, stock: 3, needsPrice: true);
    final product = await ProductRepository(db).getById(pid);

    final cart = container.read(cartControllerProvider.notifier);
    final added = cart.addProduct(product!);

    expect(added, isFalse);
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('setelah harga diisi (>0) & penanda lepas → bisa masuk keranjang',
      () async {
    final repo = ProductRepository(db);
    final pid = await buildProduct(db,
        name: 'Sprite', sellingPrice: 0, stock: 3, needsPrice: true);

    // Lengkapi harga jual → update melepas penanda needsPrice.
    await repo.update(pid, name: 'Sprite', sellingPrice: 5000, stock: 3);
    final product = await repo.getById(pid);
    expect(product!.needsPrice, isFalse);

    final cart = container.read(cartControllerProvider.notifier);
    final added = cart.addProduct(product);

    expect(added, isTrue);
    expect(container.read(cartControllerProvider).totalQty, 1);
  });
}
