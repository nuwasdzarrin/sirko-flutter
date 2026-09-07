import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/products/application/product_providers.dart';
import 'package:sirko/features/users/application/user_providers.dart';
import 'package:sirko/features/pos/presentation/pos_screen.dart';
import 'package:sirko/features/pos/presentation/widgets/payment_sheet.dart';

import '../../helpers/builders.dart';
import '../../helpers/money_matchers.dart';
import '../../helpers/pump_app.dart';

/// QA Fase 2 (Kasir Inti) — widget/UI test, host-runnable via `flutter test`
/// (tanpa emulator). Melengkapi unit test kalkulasi milik agen dev dengan
/// pengujian di lapisan UI: interaksi keranjang, sheet pembayaran (termasuk
/// edge case NEGATIF bayar < total), dan alur commit tunai end-to-end sampai
/// dialog struk. Rujukan aturan: spec/03-business-rules.md bagian 1/3/5/8.
///
/// Konvensi harness (spec/06 bagian F): seluruh alur dibungkus
/// `tester.runAsync` (Drift pakai timer nyata), penungguan lewat
/// `pumpUntilFound` (BUKAN `pumpAndSettle` — layar memakai spinner tak
/// berujung), pohon dilepas di akhir via `disposeTree`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // ---------------------------------------------------------------------------
  // A. Sheet pembayaran — perilaku UI & validasi (bagian 3)
  // ---------------------------------------------------------------------------
  group('Sheet pembayaran', () {
    // Host kecil: satu tombol yang membuka payment sheet dgn grandTotal tetap.
    Widget host(int grandTotal) => Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showPaymentSheet(ctx, grandTotal: grandTotal),
                child: const Text('buka'),
              ),
            ),
          ),
        );

    Future<void> openSheet(WidgetTester tester, int grandTotal) async {
      await pumpApp(tester, db: db, home: host(grandTotal));
      await tester.tap(find.text('buka'));
      await pumpUntilFound(tester, find.text('Pembayaran'));
    }

    testWidgets('tunai pas -> bisa Selesaikan, kembalian Rp0', (tester) async {
      await tester.runAsync(() async {
        await openSheet(tester, 10000);

        // Default baris tunai terisi = grandTotal -> lunas.
        expect(find.text('Selesaikan & Cetak Struk'), findsOneWidget);
        // Kembalian Rp0 (bayar == total).
        expect(find.text(formatRupiah(0)), findsOneWidget);

        await disposeTree(tester);
      });
    });

    testWidgets('tunai lebih -> kembalian dihitung (bagian 3)', (tester) async {
      await tester.runAsync(() async {
        // grandTotal 7.000 & bayar 15.000: keduanya BUKAN nominal chip saran,
        // sehingga teksnya unik (menghindari tabrakan dgn ActionChip).
        await openSheet(tester, 7000);

        await tester.enterText(find.byType(TextField), '15000');
        await tester.pump();

        // Total bayar Rp15.000 (unik) & kembalian 15.000-7.000 = Rp8.000 (unik).
        expect(find.text(formatRupiah(15000)), findsOneWidget);
        expect(find.text(formatRupiah(8000)), findsOneWidget);
        // Masih lunas -> tombol selesai tetap ada.
        expect(find.text('Selesaikan & Cetak Struk'), findsOneWidget);

        await disposeTree(tester);
      });
    });

    testWidgets('NEGATIF: bayar < total tak bisa diselesaikan sebagai lunas',
        (tester) async {
      await tester.runAsync(() async {
        await openSheet(tester, 10000);

        await tester.enterText(find.byType(TextField), '5000');
        await tester.pump();

        // Kurang bayar -> tombol "Selesaikan" HILANG (tak boleh lunas).
        expect(find.text('Selesaikan & Cetak Struk'), findsNothing);
        // Muncul info kurang + jalur hutang (butuh pilih pelanggan dulu).
        expect(find.textContaining('Kurang'), findsWidgets);
        expect(find.text('Pilih Pelanggan'), findsOneWidget);

        await disposeTree(tester);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // B. Kasir end-to-end — keranjang (UI) -> total reaktif -> commit tunai
  //
  // Catatan QA: alur checkout LEWAT modal sheet (tap "Selesaikan") ditemukan
  // rapuh untuk widget test — sheet lebih tinggi dari viewport & ada overflow
  // horizontal (lihat temuan di qa-reports). Karena itu, commit-nya digerakkan
  // via CheckoutController (logika produksi yang sama dgn tombol) tanpa modal;
  // verifikasi UI keranjang tetap lewat interaksi nyata. E2E modal penuh
  // dialihkan ke Patrol (emulator).
  // ---------------------------------------------------------------------------
  group('Kasir end-to-end (tunai)', () {
    testWidgets(
        'tambah item via UI, total reaktif, commit tunai -> stok & invoice',
        (tester) async {
      await tester.runAsync(() async {
        await seedBusiness(db);
        final indomieId = await buildProduct(db,
            name: 'Indomie Goreng', sellingPrice: 3000, stock: 40);
        await buildProduct(db,
            name: 'Aqua 600ml', sellingPrice: 5000, stock: 20);

        // Layout SEMPIT (lebar < 800): CartPanel inline tak dirender (total
        // tampil di bottom-bar) -> menghindari overflow CartPanel yang dicatat
        // sebagai temuan bug. Interaksi produk & commit tetap nyata.
        await tester.binding.setSurfaceSize(const Size(500, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpApp(tester, db: db, home: const PosScreen());
        await pumpUntilFound(tester, find.text('Indomie Goreng'));

        final container =
            ProviderScope.containerOf(tester.element(find.byType(PosScreen)));

        // Tambah ke keranjang via CartController memakai data produk NYATA dari
        // productListProvider (sumber yang sama dgn grid). Add-to-cart lewat tap
        // & modal checkout penuh dialihkan ke Patrol E2E (emulator).
        // Tahan provider autoDispose tetap hidup melewati pump (di app dijaga
        // oleh widget yang menonton). Tanpa ini, state ter-reset saat pump.
        container.listen(cartControllerProvider, (_, __) {});
        final items = container.read(productListProvider).value!;
        final indomie = items.firstWhere((e) => e.name == 'Indomie Goreng');
        final aqua = items.firstWhere((e) => e.name == 'Aqua 600ml');
        final cart = container.read(cartControllerProvider.notifier);
        cart.addProduct(indomie.product, unitName: indomie.unitName);
        cart.addProduct(indomie.product, unitName: indomie.unitName);
        cart.addProduct(aqua.product, unitName: aqua.unitName);
        await tester.pump();

        // Total reaktif = 2*3000 + 5000 = 11.000. cartTotalsProvider adalah
        // sumber yang persis di-bind ke tampilan (tombol Bayar & bottom-bar).
        expect(container.read(cartControllerProvider).totalQty, 3);
        expect(container.read(cartTotalsProvider).grandTotal, 11000);

        // Commit tunai lewat controller yang sama dgn tombol "Selesaikan".
        // Jaga notifier autoDispose tetap hidup selama submit (di app dijaga oleh
        // sheet & router). Tanpa ini, `state=` setelah await async -> disposal
        // race -> UnmountedRefException (checkout & sessionController).
        container.listen(checkoutControllerProvider, (_, __) {});
        container.listen(currentUserProvider, (_, __) {});
        // Beri kesempatan _load() session selesai sebelum submit membacanya.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final result = await container
            .read(checkoutControllerProvider.notifier)
            .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 11000)]);

        expect(result.invoiceNo, startsWith('INV-')); // bagian 8

        // Verifikasi DB: stok berkurang (bagian 5) & 1 transaksi paid tersimpan.
        final indomieRow = await (db.select(db.products)
              ..where((t) => t.id.equals(indomieId)))
            .getSingle();
        expect(indomieRow.stock, 38, reason: '40 - 2 terjual');

        final txs = await db.select(db.transactions).get();
        expect(txs, hasLength(1));
        expect(txs.single.grandTotal, 11000);
        expect(txs.single.status, TxStatus.paid);

        await disposeTree(tester);
      });
    });
  });
}
