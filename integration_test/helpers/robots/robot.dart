import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Basis pola **Robot / Page-Object** (spec/06 §F). Setiap layar punya robot
/// yang membungkus finder & interaksinya, agar test terbaca
/// (`OnboardingRobot.setToko(...)`) dan tahan perubahan UI.
///
/// Robot beroperasi di level [WidgetTester] sehingga dipakai ulang oleh:
/// - widget/host test (`flutter test`) via `tester`, dan
/// - E2E Patrol (`patrol test`) via `$.tester`.
///
/// Penungguan **deterministik** (tanpa sleep acak / `pumpAndSettle`): layar
/// Sirko memakai `CircularProgressIndicator` beranimasi tak-berujung yang
/// menggantungkan `pumpAndSettle`. Loop `pump()` + delay nyata berlaku baik di
/// FakeAsync host (di dalam `runAsync`) maupun binding integrasi.
abstract class Robot {
  Robot(this.tester);

  final WidgetTester tester;

  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Tidak ditemukan dalam ${timeout.inSeconds}s: $finder');
  }

  Future<void> pumpUntilGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (finder.evaluate().isEmpty) return;
    }
    throw TestFailure('Masih ada setelah ${timeout.inSeconds}s: $finder');
  }

  Future<void> settle({int frames = 14}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Field form menurut **label** InputDecoration-nya (mis. `'PIN'`) — tahan
  /// terhadap field layar lain yang masih termount selama transisi, sehingga
  /// tak mengandalkan urutan indeks `byType(TextFormField)`.
  Finder fieldByLabel(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(TextFormField))
      .first;

  /// Tombol utama menurut **label uniknya**, tahan-transisi: mencari
  /// `FilledButton` (termasuk varian `.icon` → `_FilledButtonWithIcon`) yang
  /// membungkus teks [label]. Memakai label unik menghindari ambiguitas saat
  /// tombol layar lama & baru sama-sama termount selama animasi go_router.
  Finder buttonByLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.bySubtype<FilledButton>());

  /// Tunggu tombol [label] muncul, gulir ke tampak (layar setup PIN lebih
  /// tinggi dari surface uji 800×600 sehingga tombol bisa di bawah lipatan),
  /// settle animasi, lalu tap.
  Future<void> tapButtonByLabel(String label) async {
    await pumpUntilFound(buttonByLabel(label));
    await tester.ensureVisible(buttonByLabel(label));
    await settle(); // biarkan transisi/scroll selesai agar tombol hittable
    await tester.tap(buttonByLabel(label));
    await tester.pump(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
