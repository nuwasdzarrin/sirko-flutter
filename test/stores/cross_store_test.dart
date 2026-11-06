import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/stores/domain/cross_store.dart';

/// Pemetaan produk antar-toko (KONTRAK §3b).
void main() {
  test('CopyResult: copied + skipped(ALREADY_COPIED/BARCODE_EXISTS) jadi '
      'pasangan; NOT_FOUND dipisah', () {
    final r = CopyResult.fromJson({
      'copied': [
        {
          'fromProductId': 'a',
          'toProductId': 'A',
          'variants': [
            {'fromVariantId': 'av', 'toVariantId': 'AV'}
          ]
        }
      ],
      'skipped': [
        {
          'fromProductId': 'b',
          'reason': 'ALREADY_COPIED',
          'existingProductId': 'B',
          'variants': []
        },
        {'fromProductId': 'c', 'reason': 'NOT_FOUND', 'variants': []},
      ],
    });
    expect(r.copied.single.variants, {'av': 'AV'});
    expect(r.existing.single.toProductId, 'B');
    expect(r.notFound, ['c']);
    expect(r.all.map((l) => l.fromProductId), ['a', 'b']);
  });

  test('varian tanpa pasangan di toko tujuan → tidak dikirim, dilaporkan', () {
    final plan = CrossStorePlanner.plan(const [
      TransferPick(productId: 'a', variantId: 'v9', name: 'Kopi / Pedas', qty: 1),
    ], const [
      ProductLink(fromProductId: 'a', toProductId: 'A', variants: {'v1': 'V1'}),
    ]);
    expect(plan.lines, isEmpty);
    expect(plan.unmatched, ['Kopi / Pedas']);
  });
}
