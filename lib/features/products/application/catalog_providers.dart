import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/category_repository.dart';
import '../data/unit_repository.dart';

part 'catalog_providers.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepository(ref.watch(appDatabaseProvider));

@riverpod
UnitRepository unitRepository(Ref ref) =>
    UnitRepository(ref.watch(appDatabaseProvider));

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
