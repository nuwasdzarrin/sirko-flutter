import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/core/money/money.dart';
import 'package:sirko/features/cloud/application/cloud_providers.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/subscription/application/plan_providers.dart';
import 'package:sirko/features/subscription/data/subscription_remote.dart';
import 'package:sirko/features/subscription/domain/plan.dart';
import 'package:sirko/features/subscription/presentation/juragan_screen.dart';
import 'package:sirko/features/users/application/user_providers.dart';
import 'package:sirko/features/users/domain/current_user.dart';
import 'package:sirko/features/users/domain/permission_resolver.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data[key];
  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    data.remove(key);
  }
}

final _now = DateTime.now().millisecondsSinceEpoch;

Map<String, Object?> _juraganPlan({List<String>? features}) => {
      'name': 'juragan',
      'period': 'monthly',
      'expiresAt': _now + const Duration(days: 30).inMilliseconds,
      'maxStores': 3,
      'features': features ??
          ['multi_store', 'staff', 'advanced_reports', 'receipt_branding'],
      'serverTime': _now,
    };

/// Server langganan palsu: harga J2/J9, tagihan bernominal unik, status jadi
/// confirmed setelah "admin" mengonfirmasi.
class _FakeRemote implements SubscriptionRemote {
  bool adminConfirmed = false;

  @override
  Future<PlanCatalog> catalog() async => PlanCatalog.fallback;

  @override
  Future<Checkout> checkout(PlanPeriod period) async => Checkout(
        id: 'co-1',
        period: period,
        amount: 49123,
        uniqueCode: 123,
        expiresAt: _now + const Duration(hours: 24).inMilliseconds,
      );

  @override
  Future<Checkout> status(String id) async => Checkout(
        id: id,
        period: PlanPeriod.monthly,
        amount: 49123,
        uniqueCode: 123,
        expiresAt: _now,
        status:
            adminConfirmed ? CheckoutStatus.confirmed : CheckoutStatus.pending,
        plan: adminConfirmed ? _juraganPlan() : null,
      );
}

/// Paket Juragan di app (JURAGAN.md §4): penguncian fitur + alur bayar QRIS.
void main() {
  final owner = CurrentUser(
    id: 'u0',
    name: 'Pemilik',
    username: 'owner',
    role: AppRole.owner,
    permissions: PermissionResolver.resolve(AppRole.owner),
  );

  test('penguncian NYALA: paket Warung terkunci; plan Juragan → terbuka',
      () async {
    final storage = _MemoryStorage();
    final c = ProviderContainer(overrides: [
      juraganGatingProvider.overrideWithValue(true),
      cloudTokenStoreProvider.overrideWithValue(CloudTokenStore(storage)),
    ]);
    addTearDown(c.dispose);

    expect(c.read(featureAllowedProvider(PlanFeature.staff)), isFalse);
    await c
        .read(planProvider.notifier)
        .apply(_juraganPlan(features: ['staff']));
    expect(c.read(featureAllowedProvider(PlanFeature.staff)), isTrue);
    expect(c.read(featureAllowedProvider(PlanFeature.advancedReports)),
        isFalse);
    // Tersimpan untuk dibaca lagi saat offline / app dibuka ulang.
    expect(storage.data['cloud_plan'], contains('juragan'));
  });

  test('penguncian MATI (default build): semua fitur terbuka', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    for (final f in PlanFeature.values) {
      expect(c.read(featureAllowedProvider(f)), isTrue);
    }
  });

  testWidgets('owner bayar QRIS → admin konfirmasi → Paket Juragan aktif',
      (tester) async {
    // Layar HP setinggi nyata agar seluruh isi ListView terbangun.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final storage = _MemoryStorage()..data['cloud_access_token'] = 'tok';
    final remote = _FakeRemote();
    final container = ProviderContainer(overrides: [
      juraganGatingProvider.overrideWithValue(true),
      cloudTokenStoreProvider.overrideWithValue(CloudTokenStore(storage)),
      currentUserProvider.overrideWithValue(owner),
      subscriptionRemoteProvider.overrideWithValue(remote),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: JuraganScreen(lockedFeature: PlanFeature.advancedReports)),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('termasuk Paket Juragan'), findsOneWidget);
    expect(find.textContaining(Money(49000).format()), findsOneWidget);
    expect(find.textContaining(Money(499000).format()), findsOneWidget);

    await tester.tap(find.text('Bayar dengan QRIS'));
    await tester.pump();
    await tester.pump();
    expect(find.text(Money(49123).format()), findsOneWidget);
    expect(find.textContaining('kode unik'), findsOneWidget);
    expect(container.read(planProvider).isJuragan, isFalse);

    remote.adminConfirmed = true;
    final check = find.text('Saya sudah bayar — cek status');
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Paket Juragan aktif'), findsWidgets);
    expect(container.read(planProvider).isJuragan, isTrue);
    expect(container.read(featureAllowedProvider(PlanFeature.advancedReports)),
        isTrue);

    // Unmount → timer cek-status berkala dibatalkan sebelum test selesai.
    await tester.pumpWidget(const SizedBox());
  });
}
