import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Logo toko untuk struk (paket Juragan: branding struk).
///
/// Saat diunggah, gambar langsung diolah sekali menjadi PNG **hitam-putih**
/// selebar maks [maxWidth] px — siap dicetak printer thermal 58mm (384 titik)
/// maupun ditempel di PDF — lalu disimpan di direktori dokumen aplikasi.
/// Path-nya disimpan di `businesses.logo_path` (file tidak ikut sync, sama
/// seperti foto produk).
class StoreLogoStorage {
  const StoreLogoStorage();

  static const _uuid = Uuid();
  static const _folder = 'store_logo';

  /// Lebar maksimum logo (px). Separuh lebar kertas 58mm agar tak dominan.
  static const maxWidth = 240;

  /// Olah [source] (jpg/png/…) → PNG grayscale ≤ [maxWidth] px. Latar
  /// transparan diratakan ke putih (printer thermal tak kenal alpha).
  /// Null bila bukan gambar yang bisa dibaca.
  static Uint8List? process(Uint8List source) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(source);
    } catch (_) {
      return null; // decoder melempar untuk byte acak / file rusak
    }
    if (decoded == null) return null;
    var out = img.Image(width: decoded.width, height: decoded.height)
      ..clear(img.ColorRgb8(255, 255, 255));
    out = img.compositeImage(out, decoded);
    if (out.width > maxWidth) {
      out = img.copyResize(out,
          width: maxWidth, interpolation: img.Interpolation.average);
    }
    out = img.grayscale(out);
    return Uint8List.fromList(img.encodePng(out));
  }

  /// Olah & simpan [sourcePath] (hasil image_picker); kembalikan path tujuan.
  /// Melempar [FormatException] bila file bukan gambar.
  Future<String> persist(String sourcePath) async {
    final processed = process(await File(sourcePath).readAsBytes());
    if (processed == null) {
      throw const FormatException('File bukan gambar yang didukung.');
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = p.join(dir.path, 'logo_${_uuid.v4()}.png');
    await File(dest).writeAsBytes(processed, flush: true);
    return dest;
  }

  /// Baca logo untuk dicetak; null bila path kosong / file hilang.
  Future<Uint8List?> read(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Hapus file logo lama (best-effort).
  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
