import 'dart:math';

import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/stores/data/store_remote.dart';

/// Daftar akun pemilik + toko pertama lewat alur baru (KONTRAK akun):
/// register → OTP (`devCode`, butuh backend lokal `AUTH_DEV_OTP_ECHO=true`)
/// → verify-email → POST /v1/businesses. Return sesi toko (sudah disimpan).
Future<SessionPayload> registerOwnerWithStore(
  CloudAuthRepository auth,
  CloudApiClient api, {
  required String email,
  required String storeName,
  String name = 'Budi',
  String password = 'rahasia123',
}) async {
  final phone = '0812${Random().nextInt(90000000) + 10000000}';
  final sent = await auth.register(
      name: name, email: email, phone: phone, password: password);
  final code = sent.devCode;
  if (code == null) {
    throw StateError('Backend uji harus memakai AUTH_DEV_OTP_ECHO=true '
        '(kode OTP ikut di respons).');
  }
  await auth.verifyEmail(email, code);
  final store = await HttpStoreRemote(api).createBusiness(storeName);
  return auth.applySession(store);
}
