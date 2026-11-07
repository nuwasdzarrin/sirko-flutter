import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';

/// Pengaturan pemilik: metode bayar yang tampil di kasir & izin split.
void main() {
  late AppDatabase db;
  late AppSettingsRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('bawaan: semua metode & split boleh', () async {
    expect(await repo.paymentMethods(), PaymentMethod.values.toSet());
    expect(await repo.allowSplitPayment(), isTrue);
  });

  test('pemilik memilih metode; tunai selalu ada; split bisa dimatikan',
      () async {
    await repo.setPaymentMethods({PaymentMethod.qris});
    expect(await repo.paymentMethods(),
        {PaymentMethod.cash, PaymentMethod.qris});
    await repo.setAllowSplitPayment(false);
    expect(await repo.allowSplitPayment(), isFalse);
  });
}
