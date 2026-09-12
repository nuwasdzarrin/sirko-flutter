import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../pos/application/pos_providers.dart';
import '../data/catalog_seed_importer.dart';
import '../data/category_repository.dart';
import '../data/public_catalog_repository.dart';
import '../data/unit_repository.dart';

part 'catalog_providers.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepository(ref.watch(appDatabaseProvider));

@riverpod
UnitRepository unitRepository(Ref ref) =>
    UnitRepository(ref.watch(appDatabaseProvider));

/// Katalog publik lokal (seed). Repository return tipe non-Drift → aman gen.
@riverpod
PublicCatalogRepository publicCatalogRepository(Ref ref) =>
    PublicCatalogRepository(ref.watch(appDatabaseProvider));

/// Importer seed katalog (first-run). Butuh [appSettingsRepositoryProvider]
/// untuk gate versi (idempoten).
@riverpod
CatalogSeedImporter catalogSeedImporter(Ref ref) => CatalogSeedImporter(
      ref.watch(appDatabaseProvider),
      ref.watch(appSettingsRepositoryProvider),
    );

/// Thumbnail katalog per-barcode (BLOB lokal). Ditulis manual (family) &
/// autoDispose — dibaca hanya saat render tile/prefill (spec 13 §6.5).
final catalogThumbProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, barcode) => ref.watch(publicCatalogRepositoryProvider).getThumb(barcode),
);

/// Daftar kategori & satuan reaktif (dropdown form, chip filter, kelola).
///
/// Ditulis manual (bukan `@riverpod`) karena riverpod_generator 3.0.3 gagal
/// menstringifikasi tipe baris Drift ([Category]/[Unit]) yang berada di file
/// `part` (app_database.g.dart) → `InvalidTypeException`. Provider manual tetap
/// bisa membaca provider repository hasil code-gen.
final categoryListProvider = StreamProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

final unitListProvider = StreamProvider.autoDispose<List<Unit>>(
  (ref) => ref.watch(unitRepositoryProvider).watchUnits(),
);
