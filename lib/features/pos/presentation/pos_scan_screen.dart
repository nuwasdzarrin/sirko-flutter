import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Umpan balik hasil satu scan untuk ditampilkan di scanner (R2).
class ScanFeedback {
  final String message;
  final bool success;
  const ScanFeedback(this.message, {this.success = true});
}

/// Scanner kasir **mode beruntun** (R2): kamera tetap terbuka setelah tiap
/// deteksi agar kasir bisa scan banyak item; tombol **Selesai** untuk menutup.
///
/// Resolusi barcode → keranjang ditangani oleh [onCode] (di layar kasir), yang
/// mengembalikan [ScanFeedback] untuk ditampilkan sebagai toast + getar.
/// Izin kamera diminta runtime; bila ditolak permanen, ada jalan ke Pengaturan.
class PosScanScreen extends StatefulWidget {
  final Future<ScanFeedback> Function(String code) onCode;
  const PosScanScreen({super.key, required this.onCode});

  @override
  State<PosScanScreen> createState() => _PosScanScreenState();
}

class _PosScanScreenState extends State<PosScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  /// Status izin kamera: null = sedang meminta.
  bool? _granted;

  /// Sedang memproses satu kode (cegah deteksi ganda beruntun).
  bool _processing = false;
  ScanFeedback? _lastFeedback;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _granted = status.isGranted);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;

    setState(() => _processing = true);
    final feedback = await widget.onCode(code);
    unawaited(
        feedback.success ? HapticFeedback.mediumImpact() : HapticFeedback.vibrate());
    if (!mounted) return;
    setState(() => _lastFeedback = feedback);
    // Cooldown singkat agar barcode sama bisa di-scan ulang (mis. qty +1) dan
    // menghindari deteksi ganda pada frame berturut-turut.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Produk'),
        actions: [
          if (_granted == true) ...[
            IconButton(
              tooltip: 'Nyala/mati senter',
              icon: const Icon(Icons.flashlight_on_outlined),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              tooltip: 'Ganti kamera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ],
      ),
      body: switch (_granted) {
        null => const Center(child: CircularProgressIndicator()),
        false => _PermissionDenied(onRetry: _requestPermission),
        true => _scanner(context),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('Selesai'),
          ),
        ),
      ),
    );
  }

  Widget _scanner(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _PermissionDenied(
            onRetry: _requestPermission,
            message: 'Kamera tidak tersedia: ${error.errorCode}',
          ),
        ),
        // Bingkai bantu arah scan.
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const Positioned(
          top: 24,
          child: Text(
            'Arahkan ke barcode — scan beruntun',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        if (_lastFeedback != null)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: _FeedbackBanner(feedback: _lastFeedback!),
          ),
      ],
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final ScanFeedback feedback;
  const _FeedbackBanner({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final color = feedback.success ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(feedback.success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(feedback.message,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const _PermissionDenied({required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              message ??
                  'Izin kamera diperlukan untuk scan barcode. '
                      'Aktifkan izin kamera untuk melanjutkan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54)),
                  child: const Text('Coba lagi'),
                ),
                FilledButton(
                  onPressed: openAppSettings,
                  child: const Text('Buka Pengaturan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
