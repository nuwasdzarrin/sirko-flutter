import 'package:flutter_contacts/flutter_contacts.dart';

/// Satu kontak HP yang bisa diimpor jadi pelanggan.
class ContactCandidate {
  final String name;
  final String? phone;
  const ContactCandidate({required this.name, this.phone});
}

/// Akses kontak HP (opsional, Fase 4). Membungkus `flutter_contacts` + izin
/// runtime. Semua metode aman-gagal: bila izin ditolak, lempar
/// [ContactPermissionDenied] agar UI bisa memberi pesan ramah.
class ContactImportService {
  const ContactImportService();

  /// Minta izin & ambil kontak (nama + 1 telepon utama). Diurutkan by nama.
  Future<List<ContactCandidate>> fetchContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) throw const ContactPermissionDenied();

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: false,
    );
    final out = <ContactCandidate>[];
    for (final c in contacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      final phone = c.phones.isNotEmpty ? c.phones.first.number.trim() : null;
      out.add(ContactCandidate(
        name: name,
        phone: (phone != null && phone.isEmpty) ? null : phone,
      ));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }
}

/// Izin kontak ditolak pengguna.
class ContactPermissionDenied implements Exception {
  const ContactPermissionDenied();
  @override
  String toString() => 'Izin akses kontak ditolak.';
}
