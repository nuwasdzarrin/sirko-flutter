import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sirko/core/media/image_compressor.dart';

/// Foto unggahan (usulan katalog): JPEG ≤200 KB + nama berkas rapi.
void main() {
  test('foto besar & "berisik" dikompres ≤200 KB', () {
    // 3000×2000 piksel acak ≈ foto kamera yang sulit dikompres.
    final r = Random(7);
    final big = img.Image(width: 3000, height: 2000);
    for (final p in big) {
      p
        ..r = r.nextInt(256)
        ..g = r.nextInt(256)
        ..b = r.nextInt(256);
    }
    final source = Uint8List.fromList(img.encodePng(big));
    expect(source.length, greaterThan(kMaxUploadImageBytes));

    final out = compressJpeg(source, kMaxUploadImageBytes);
    expect(out.length, lessThanOrEqualTo(kMaxUploadImageBytes));
    expect(img.decodeJpg(out), isNotNull);
  });

  test('nama berkas: spasi → "-", + 6 huruf kecil/angka, .jpg', () {
    final name = uploadFileName('Aqua Botol  600ml (baru).PNG',
        random: Random(1));
    expect(name, matches(RegExp(r'^Aqua-Botol-600ml-baru-[a-z0-9]{6}\.jpg$')));
    expect(uploadFileName('/storage/emulated/0/DCIM/IMG 2026.jpeg'),
        matches(RegExp(r'^IMG-2026-[a-z0-9]{6}\.jpg$')));
    expect(uploadFileName('   .png'), matches(RegExp(r'^foto-[a-z0-9]{6}\.jpg$')));
  });
}
