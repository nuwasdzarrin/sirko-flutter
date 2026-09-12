import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/features/products/application/stock_in_providers.dart';
import 'package:sirko/features/products/domain/stock_in_draft.dart';

/// Buffer sesi Stok Masuk: agregasi per-barcode, koreksi qty, hapus.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(stockInControllerProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  StockInDraftLine line(String barcode) => StockInDraftLine(
        barcode: barcode,
        name: 'P-$barcode',
        qty: 1,
        source: StockInSource.manualNew,
      );

  test('scan barcode sama beruntun → qty diagregasi (N → N+1)', () {
    final ctrl = container.read(stockInControllerProvider.notifier);
    expect(ctrl.addOrIncrement(line('a')), 1);
    expect(ctrl.addOrIncrement(line('a')), 2);
    expect(ctrl.addOrIncrement(line('a')), 3);
    expect(container.read(stockInControllerProvider).length, 1);
    expect(ctrl.totalQty, 3);
  });

  test('koreksi qty & hapus baris sebelum simpan', () {
    final ctrl = container.read(stockInControllerProvider.notifier);
    ctrl.addOrIncrement(line('a'));
    ctrl.addOrIncrement(line('b'));
    ctrl.setQty('a', 5);
    expect(ctrl.lineFor('a')!.qty, 5);

    ctrl.decrement('b'); // 1 → 0 → terhapus.
    expect(ctrl.lineFor('b'), isNull);
    expect(container.read(stockInControllerProvider).length, 1);

    ctrl.remove('a');
    expect(container.read(stockInControllerProvider), isEmpty);
  });
}
