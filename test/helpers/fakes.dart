import 'package:sirko/features/auth/data/pin_hasher.dart';
import 'package:sirko/features/auth/data/pin_repository.dart';
import 'package:sirko/features/customers/data/contact_import_service.dart';
import 'package:sirko/features/pos/data/receipt_thermal_printer.dart';
import 'package:sirko/features/pos/domain/receipt_data.dart';

/// Fake service hardware (spec/06 §B, §E prasyarat #1 & #4).
///
/// Semua perangkat keras (printer BT, kontak, biometrik, secure storage) berada
/// di balik provider yang bisa di-`override`. Fake di sini menggantikannya saat
/// test agar tak butuh perangkat fisik dan hasilnya deterministik.
///
/// Catatan testability: scanner kamera (`BarcodeScannerScreen`) **belum** punya
/// provider yang bisa di-fake — lihat laporan qa-reports (temuan G2).

/// Printer thermal palsu: mencatat panggilan cetak alih-alih mengirim byte BT.
class FakeReceiptThermalPrinter extends ReceiptThermalPrinter {
  FakeReceiptThermalPrinter({this.bluetoothEnabled = true});

  final bool bluetoothEnabled;

  /// Semua struk yang "dicetak" selama test (untuk assert alur cetak).
  final List<ReceiptData> printed = <ReceiptData>[];
  int connectCount = 0;

  @override
  Future<bool> isBluetoothEnabled() async => bluetoothEnabled;

  @override
  Future<List<ThermalDevice>> pairedDevices() async => const [
        ThermalDevice(name: 'Fake Printer 58mm', mac: '00:11:22:33:44:55'),
      ];

  @override
  Future<bool> get isConnected async => connectCount > 0;

  @override
  Future<bool> printReceipt(
    ReceiptData data, {
    required String mac,
    ReceiptPaperSize size = ReceiptPaperSize.mm58,
  }) async {
    connectCount++;
    printed.add(data);
    return true;
  }

  @override
  Future<void> disconnect() async {}
}

/// Layanan kontak palsu: kembalikan daftar terkontrol, atau lempar
/// [ContactPermissionDenied] bila [denyPermission] true (uji jalur izin ditolak).
class FakeContactImportService extends ContactImportService {
  FakeContactImportService({
    this.contacts = const [],
    this.denyPermission = false,
  });

  final List<ContactCandidate> contacts;
  final bool denyPermission;

  @override
  Future<List<ContactCandidate>> fetchContacts() async {
    if (denyPermission) throw const ContactPermissionDenied();
    return contacts;
  }
}

/// PIN repository palsu: menyimpan kredensial di memori (bukan Keystore OS),
/// sehingga aman dijalankan sebagai host `flutter test` tanpa plugin
/// `flutter_secure_storage`. Tetap memakai [PinHasher] asli agar verifikasi
/// PIN berperilaku sama seperti produksi (§13).
class FakePinRepository extends PinRepository {
  // super() memakai FlutterSecureStorage default, tapi tak pernah dipanggil
  // karena seluruh metode di-override menjadi in-memory.
  FakePinRepository({String? initialPin}) {
    if (initialPin != null) _credential = PinHasher.hash(initialPin);
  }

  String? _credential; // "saltB64:hashB64"

  @override
  Future<bool> isPinSet() async => _credential != null;

  @override
  Future<void> setPin(String pin) async => _credential = PinHasher.hash(pin);

  @override
  Future<bool> verifyPin(String pin) async {
    final c = _credential;
    if (c == null) return false;
    return PinHasher.verify(pin, c);
  }

  @override
  Future<String?> exportLegacyCredential() async => _credential;

  @override
  Future<void> clear() async => _credential = null;
}
