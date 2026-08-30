import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Menyimpan foto produk ke direktori dokumen aplikasi (path stabil),
/// bukan cache sementara dari image_picker. Path inilah yang disimpan di
/// `products.imagePath`.
class ProductImageStorage {
  const ProductImageStorage();

  static const _uuid = Uuid();
  static const _folder = 'product_images';

  /// Salin file [sourcePath] (hasil image_picker) ke direktori dokumen dan
  /// kembalikan path tujuan yang stabil.
  Future<String> persist(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Hapus file foto bila ada (best-effort, tak melempar).
  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best-effort — abaikan kegagalan hapus file.
    }
  }
}
