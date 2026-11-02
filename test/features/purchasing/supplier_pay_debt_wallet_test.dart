import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/features/purchasing/presentation/supplier_detail_screen.dart';

import '../../helpers/pump_app.dart';

/// BUG-05: dialog "Bayar Hutang" supplier harus menawarkan wallet sebagai
/// sumber kas (bukan hanya "— Tanpa kas —").
void main() {
  testWidgets('dropdown "Ambil dari kas" memuat wallet aktif', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(
            id: 's1',
            name: 'CV Sumber Rejeki',
            debtBalance: const Value(325000),
            createdAt: 0,
            updatedAt: 0,
          ));
      await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: 'w1',
            name: 'Kas Utama',
            type: WalletType.cash,
            balance: const Value(32000),
            createdAt: 0,
            updatedAt: 0,
          ));
      await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: 'w2',
            name: 'Bank BCA',
            type: WalletType.bank,
            balance: const Value(110000),
            createdAt: 1,
            updatedAt: 1,
          ));

      await pumpApp(tester,
          db: db, home: const SupplierDetailScreen(supplierId: 's1'));
      await pumpUntilFound(tester, find.text('Bayar Hutang'));

      await tester.tap(find.text('Bayar Hutang'));
      await pumpUntilFound(tester, find.text('Ambil dari kas (opsional)'));
      await tester.tap(find.text('Ambil dari kas (opsional)'));
      await pumpUntilFound(tester, find.textContaining('Bank BCA'),
          timeout: const Duration(seconds: 4));

      expect(find.textContaining('Kas Utama'), findsWidgets);
      expect(find.textContaining('Bank BCA'), findsWidgets);

      await disposeTree(tester);
    });
    await db.close();
  });
}
