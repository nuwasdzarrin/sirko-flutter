import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot.dart';

/// Robot layar **Onboarding** (buat toko pertama, Fase 0).
class OnboardingRobot extends Robot {
  OnboardingRobot(super.tester);

  /// Pastikan layar onboarding tampil (redirect dari splash saat belum ada toko).
  Future<void> verifyDitampilkan() =>
      pumpUntilFound(find.text('Buat data toko Anda untuk memulai.'));

  /// Isi nama toko lalu tekan "Lanjut" → lanjut ke pembuatan PIN owner.
  Future<void> setToko(String nama) async {
    await tester.enterText(find.byType(TextFormField).first, nama);
    await tapButtonByLabel('Lanjut');
  }
}
