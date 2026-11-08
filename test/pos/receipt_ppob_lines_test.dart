import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/pos/domain/receipt_data.dart';

/// Struk: nama item PPOB (dipisah " · ") dipecah jadi judul + rincian
/// berlabel; barang biasa tetap satu baris.
void main() {
  ReceiptLine line(String name) => ReceiptLine(
      name: name, qty: 1, unitPrice: 1, discount: 0, lineTotal: 1);

  test('token PLN: No, Nama, Token (tebal), Ref', () {
    final l = line('Token PLN 20.000 · 86300988184 · a.n. ENI YUNIATUN,S.E 2 '
        '· Token 8054-0896-3210-7854-2136 · #6ef05a49');
    expect(l.title, 'Token PLN 20.000');
    expect(l.details.map((d) => d.text), [
      'No: 86300988184',
      'Nama: ENI YUNIATUN,S.E 2',
      'Token: 8054-0896-3210-7854-2136',
      'Ref: 6ef05a49',
    ]);
    expect(l.details[2].emphasis, isTrue);
  });

  test('pulsa diproses: Status', () {
    final l = line('Telkomsel 20.000 · 081213240016 · DIPROSES · #54a3cfe4');
    expect(l.details.map((d) => d.text),
        ['No: 081213240016', 'Status: Diproses', 'Ref: 54a3cfe4']);
  });

  test('barang biasa: tanpa rincian', () {
    final l = line('Aqua Botol 600ml');
    expect(l.title, 'Aqua Botol 600ml');
    expect(l.details, isEmpty);
  });
}
