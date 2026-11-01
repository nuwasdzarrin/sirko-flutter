import 'package:flutter/widgets.dart';

/// Penanda id **stabil** untuk automation E2E (Maestro `id:` / UiAutomator
/// resource-id di Android). Dipakai untuk tombol ikon yang hanya punya
/// `tooltip` — tooltip Flutter tak terbaca oleh alat automation.
///
/// Tidak menambah teks yang dibacakan screen reader (tooltip tetap labelnya).
class TestId extends StatelessWidget {
  final String id;
  final Widget child;

  const TestId(this.id, {super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Semantics(identifier: id, container: true, child: child);
}
