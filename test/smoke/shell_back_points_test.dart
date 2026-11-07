import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/ppob/application/ppob_providers.dart';
import 'package:sirko/features/ppob/data/ppob_models.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// Shell: saldo Poin di AppBar; tombol back HP mengikuti riwayat tab, dan
/// riwayat habis → konfirmasi keluar (bukan langsung keluar).
void main() {
  late AppDatabase db;
  setUp(() => db = createMemoryDb());
  tearDown(() => db.close());

  final status = PpobStatus.fromJson({
    'enabled': true,
    'categories': [],
    'points': {
      'available': true,
      'balance': 78185,
      'canTopup': true,
      'minTopup': 20000,
      'maxTopup': 5000000
    },
  });

  Future<void> boot(WidgetTester tester) async {
    await seedBusiness(db, name: 'Warung Berkah');
    await pumpFullApp(tester,
        db: db,
        secureStorage: FakeSecureStorage.signedInOwner(name: 'Bu Sri'),
        overrides: [
          ppobStatusProvider.overrideWith((ref) async => status),
        ]);
    await pumpUntilFound(tester, find.text('Rp78.185'));
  }

  testWidgets('saldo Poin tampil di AppBar', (tester) async {
    await tester.runAsync(() async {
      await boot(tester);
      expect(find.text('Rp78.185'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('back → tab sebelumnya; riwayat habis → konfirmasi keluar',
      (tester) async {
    await tester.runAsync(() async {
      await boot(tester);
      await tester.tap(find.text('Produk').last);
      await pumpUntilFound(tester, find.text('Fisik'));

      await tester.binding.handlePopRoute(); // tombol back HP
      await pumpUntilFound(tester, find.text('Beranda').first);
      expect(find.text('Keluar dari Sirko?'), findsNothing);

      await tester.binding.handlePopRoute(); // riwayat habis
      await pumpUntilFound(tester, find.text('Keluar dari Sirko?'));
      await tester.tap(find.text('Batal'));
      await pumpUntilFound(tester, find.text('Rp78.185'));
      expect(find.text('Keluar dari Sirko?'), findsNothing);

      await disposeTree(tester);
    });
  });
}
