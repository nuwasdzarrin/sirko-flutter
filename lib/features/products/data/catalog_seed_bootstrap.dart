import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'catalog_seed_importer.dart';

/// Path aset seed yang dibundel (didaftarkan di pubspec).
const catalogSeedAsset = 'assets/seed/catalog_seed.sqlite';

/// Jalankan import seed katalog first-run: salin aset bundel → file temp →
/// [CatalogSeedImporter.importIfNeeded] (idempoten, di dalam SQLite).
///
/// Return `true` bila import benar dijalankan, `false` bila di-skip. Aman
/// dipanggil tiap boot; kerja berat (bulk insert) hanya sekali per versi seed.
Future<bool> runCatalogSeedImport(CatalogSeedImporter importer) async {
  if (await importer.isImported()) return false;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/catalog_seed_import.sqlite');
  final data = await rootBundle.load(catalogSeedAsset);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );

  try {
    return await importer.importIfNeeded(file);
  } finally {
    // Bersihkan file temp; abaikan kegagalan hapus.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
