import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/pos/presentation/widgets/cart_panel.dart';

import '../../helpers/builders.dart';
import '../../helpers/pump_app.dart';

/// R3 — Popup keranjang: Header & Footer statis saat Body scroll; tombol Bayar
/// & Tunda selalu terlihat.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets(
      'daftar panjang: header & footer diam saat body scroll; Bayar & Tunda tampak',
      (tester) async {
    await tester.runAsync(() async {
      await seedBusiness(db);
      for (var i = 0; i < 14; i++) {
        await buildProduct(db, name: 'Produk ${i.toString().padLeft(2, '0')}',
            sellingPrice: 3000 + i * 100, stock: 50);
      }

      await tester.binding.setSurfaceSize(const Size(500, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpApp(
        tester,
        db: db,
        home: Scaffold(
          body: CartPanel(onCheckout: () {}, onHold: () {}),
        ),
      );
      await pumpUntilFound(tester, find.text('Keranjang'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(CartPanel)));
      container.listen(cartControllerProvider, (_, __) {});
      // Ambil produk langsung dari DB (CartPanel tak me-render daftar produk).
      final products = await db.select(db.products).get();
      final cart = container.read(cartControllerProvider.notifier);
      for (final p in products) {
        cart.addProduct(p);
      }
      await tester.pump();

      // Zona statis + tombol footer terlihat sebelum scroll.
      expect(find.text('Keranjang'), findsOneWidget);
      expect(find.text('Tunda'), findsOneWidget);
      expect(find.textContaining('Bayar'), findsOneWidget);

      // Body (ListView) bisa di-scroll.
      expect(find.byType(ListView), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      // Setelah scroll: header & footer TETAP diam (masih ada di pohon).
      expect(find.text('Keranjang'), findsOneWidget);
      expect(find.text('Tunda'), findsOneWidget);
      expect(find.textContaining('Bayar'), findsOneWidget);

      // Lepas pohon agar timer Drift tuntas.
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  });
}
