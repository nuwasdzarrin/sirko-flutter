import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/features/users/data/user_repository.dart';

/// Pemilik akun cloud = baris owner lokal **tanpa PIN** (KONTRAK akun: tidak
/// ada PIN pemilik). Karyawan (Juragan) tetap memakai PIN.
void main() {
  late AppDatabase db;
  late UserRepository users;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    users = UserRepository(db);
  });
  tearDown(() => db.close());

  test('membuat pemilik tanpa PIN sekali; dipanggil ulang tidak menggandakan',
      () async {
    final a = await users.ensureCloudOwner(name: 'Sri Wahyuni');
    final b = await users.ensureCloudOwner(name: 'Sri Wahyuni');

    expect(a.id, b.id);
    expect(a.role, AppRole.owner);
    expect(a.pinHash, UserRepository.noPin);
    expect(await db.select(db.users).get(), hasLength(1));
  });

  test('nama pemilik ikut nama akun terbaru', () async {
    await users.ensureCloudOwner(name: 'Sri');
    final o = await users.ensureCloudOwner(name: 'Sri Wahyuni');
    expect(o.name, 'Sri Wahyuni');
  });

  test('pemilik tanpa PIN tidak muncul di daftar login PIN; karyawan muncul',
      () async {
    await users.ensureCloudOwner(name: 'Sri');
    await users.create(
        name: 'Kasir Ani',
        username: 'ani',
        pin: '135790',
        role: AppRole.cashier);

    final loginable = await users.watchLoginableUsers().first;
    expect(loginable.map((u) => u.name), ['Kasir Ani']);
  });
}
