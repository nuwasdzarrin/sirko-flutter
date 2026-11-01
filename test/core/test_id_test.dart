import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/widgets/test_id.dart';

/// QA-M1: tombol ikon ber-tooltip harus punya id semantics stabil
/// (resource-id Android) agar bisa diketuk automation tanpa koordinat.
void main() {
  testWidgets('TestId memberi identifier semantics pada tombol ikon',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestId(
          'kasir_riwayat',
          child: IconButton(
            tooltip: 'Riwayat transaksi',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => tapped = true,
          ),
        ),
      ),
    ));

    final byId = find.bySemanticsIdentifier('kasir_riwayat');
    expect(byId, findsOneWidget);

    await tester.tap(byId);
    expect(tapped, isTrue);
  });
}
