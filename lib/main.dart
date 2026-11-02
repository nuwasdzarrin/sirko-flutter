import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/store_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data lokal id_ID untuk format tanggal/angka.
  await initializeDateFormatting('id_ID', null);
  // Daftar toko dibaca SEBELUM DB dibuka (DB = file toko aktif).
  final stores = StoreRegistryRepository(await SharedPreferences.getInstance());
  runApp(ProviderScope(
    overrides: [
      storeRegistryRepositoryProvider.overrideWithValue(stores),
      initialStoreRegistryProvider.overrideWithValue(stores.load()),
    ],
    child: const SirkoApp(),
  ));
}
