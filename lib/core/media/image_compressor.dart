import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Batas ukuran foto yang diunggah (usulan katalog, dsb.).
const int kMaxUploadImageBytes = 200 * 1024;

/// Hasil kompresi: JPEG ≤ [kMaxUploadImageBytes] + nama berkas rapi.
class CompressedImage {
  final Uint8List bytes;
  final String fileName;
  const CompressedImage(this.bytes, this.fileName);
  String get contentType => 'image/jpeg';
}

/// Kompres gambar ke JPEG maksimal [maxBytes]: turunkan kualitas dulu, lalu
/// perkecil dimensi bila perlu. Berjalan di isolate (tidak membekukan UI).
Future<CompressedImage> compressForUpload(
  Uint8List source,
  String originalName, {
  int maxBytes = kMaxUploadImageBytes,
  Random? random,
}) async {
  final name = uploadFileName(originalName, random: random);
  final bytes = await Isolate.run(() => compressJpeg(source, maxBytes));
  return CompressedImage(bytes, name);
}

/// Inti kompresi (sinkron, murni) — dipakai isolate & test.
Uint8List compressJpeg(Uint8List source, int maxBytes) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('Berkas bukan gambar yang didukung.');
  }
  var image = img.bakeOrientation(decoded);
  // Foto produk tak perlu lebih dari 1280 px sisi terpanjang.
  image = _fit(image, 1280);
  while (true) {
    for (final q in const [85, 75, 65, 55, 45, 35]) {
      final out = img.encodeJpg(image, quality: q);
      if (out.length <= maxBytes) return out;
    }
    if (max(image.width, image.height) <= 240) {
      return img.encodeJpg(image, quality: 30); // batas bawah wajar
    }
    image = _fit(image, (max(image.width, image.height) * 0.75).round());
  }
}

img.Image _fit(img.Image image, int longest) {
  final side = max(image.width, image.height);
  if (side <= longest) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: longest)
      : img.copyResize(image, height: longest);
}

/// Nama berkas unggahan: nama asli tanpa ekstensi, spasi → "-", karakter
/// aneh dibuang, + "-" + 6 karakter acak (huruf kecil & angka) + ".jpg".
/// Contoh: "Aqua Botol 600ml.png" → "Aqua-Botol-600ml-k3x9a2.jpg".
String uploadFileName(String originalName, {Random? random}) {
  final base = originalName.split(RegExp(r'[\\/]')).last;
  final dot = base.lastIndexOf('.');
  var stem = dot > 0 ? base.substring(0, dot) : base;
  stem = stem
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (stem.isEmpty) stem = 'foto';
  if (stem.length > 60) stem = stem.substring(0, 60);
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = random ?? Random.secure();
  final suffix =
      List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  return '$stem-$suffix.jpg';
}
