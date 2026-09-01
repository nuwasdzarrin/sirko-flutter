import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot.dart';

/// Robot layar **PIN**: mencakup dua situasi berbeda dalam alur auth (Fase 6):
/// - [buatOwner]  → `SetPinScreen` (belum ada user; buat akun pemilik + PIN).
/// - [loginDenganPin] → `PinLoginScreen` (user sudah ada; login sesi ini).
class PinRobot extends Robot {
  PinRobot(super.tester);

  // --- SetPinScreen (buat akun pemilik pertama) ---

  Future<void> verifyBuatOwnerDitampilkan() =>
      pumpUntilFound(find.text('Akun Pemilik'));

  /// Isi PIN + konfirmasi lalu "Buat & Masuk". Field dicari via label agar tak
  /// tertukar dengan field layar onboarding yang masih termount saat transisi.
  Future<void> buatOwner(String pin, {String? nama}) async {
    if (nama != null) await tester.enterText(fieldByLabel('Nama pemilik'), nama);
    await tester.enterText(fieldByLabel('PIN'), pin);
    await tester.enterText(fieldByLabel('Ulangi PIN'), pin);
    await tapButtonByLabel('Buat & Masuk');
  }

  // --- PinLoginScreen (login user yang sudah ada) ---

  Future<void> verifyLoginDitampilkan() =>
      pumpUntilFound(buttonByLabel('Masuk'));

  /// Masukkan PIN pada `PinLoginScreen` (memakai `TextField`, bukan
  /// `TextFormField`) lalu tekan "Masuk".
  Future<void> loginDenganPin(String pin) async {
    await tester.enterText(find.byType(TextField).first, pin);
    await tapButtonByLabel('Masuk');
  }
}
