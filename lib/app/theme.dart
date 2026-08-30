import 'package:flutter/material.dart';

/// Tema Material 3 (light & dark) dengan `ColorScheme.fromSeed`.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF1565C0); // biru toko

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
