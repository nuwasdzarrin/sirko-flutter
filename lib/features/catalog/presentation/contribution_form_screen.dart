import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../products/presentation/barcode_scanner_screen.dart';
import '../application/catalog_umum_providers.dart';
import '../domain/catalog_item.dart';
import '../domain/contribution.dart';

/// Taksonomi kategori tetap (API.md §2).
const _kCategories = [
  'Makanan', 'Minuman', 'Rokok', 'Sembako', 'Kebersihan', 'Perawatan',
  'Kesehatan', 'Bumbu/Dapur', 'Snack', 'ATK', 'Lainnya', //
];

/// Form **usul produk** ke Katalog Umum (crowdsource). [existing] terisi bila
/// mengusulkan **perbaikan** produk katalog (kirim `targetId`).
class ContributionFormScreen extends ConsumerStatefulWidget {
  final CatalogItem? existing;
  final String? initialBarcode;
  const ContributionFormScreen({super.key, this.existing, this.initialBarcode});

  @override
  ConsumerState<ContributionFormScreen> createState() =>
      _ContributionFormScreenState();
}

class _ContributionFormScreenState
    extends ConsumerState<ContributionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _brand;
  late final TextEditingController _netSize;
  late final TextEditingController _netUnit;
  late final TextEditingController _note;
  String? _category;
  File? _photo;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _barcode =
        TextEditingController(text: e?.barcode ?? widget.initialBarcode ?? '');
    _brand = TextEditingController(text: e?.brand ?? '');
    _netSize = TextEditingController(
        text: e?.netSize == null ? '' : _numText(e!.netSize!));
    _netUnit = TextEditingController(text: e?.netUnit ?? '');
    _note = TextEditingController();
    _category = _kCategories.contains(e?.category) ? e!.category : null;
  }

  String _numText(double v) => v % 1 == 0 ? v.toInt().toString() : '$v';

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _brand.dispose();
    _netSize.dispose();
    _netUnit.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      setState(() => _barcode.text = code);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1024, imageQuality: 80);
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      String? photoUrl = widget.existing?.photoUrl;
      if (_photo != null) {
        photoUrl =
            await ref.read(cloudMediaRepositoryProvider).uploadCatalogImage(_photo!);
      }
      final netSize = double.tryParse(_netSize.text.trim().replaceAll(',', '.'));
      final input = ContributionInput(
        name: _name.text.trim(),
        barcode: _barcode.text.trim(),
        brand: _brand.text.trim(),
        category: _category,
        netSize: netSize,
        netUnit: _netUnit.text.trim(),
        photoUrl: photoUrl,
        note: _note.text.trim(),
        targetId: widget.existing?.id,
      );
      await ref.read(cloudContributionRepositoryProvider).submit(input);
      ref.invalidate(myContributionsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Usulan terkirim — menunggu review admin. '
            'Cek di "Usulan Saya".'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengirim: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Usulkan Perbaikan' : 'Usulkan Produk')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: _PhotoPreview(
                    file: _photo, existingUrl: widget.existing?.photoUrl),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama produk *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scan,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(
                labelText: 'Merek',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: _kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _netSize,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ukuran (mis. 85)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _netUnit,
                    decoration: const InputDecoration(
                      labelText: 'Satuan (g/ml)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk admin (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Mengirim…' : 'Kirim Usulan'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 8),
            Text(
              'Usulan tidak langsung masuk katalog — di-review admin dulu. '
              'Setelah disetujui, produk muncul di katalog untuk semua toko.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  const _PhotoPreview({this.file, this.existingUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (file != null) {
      child = Image.file(file!, fit: BoxFit.cover);
    } else if (existingUrl != null) {
      child = Image.network(existingUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(theme));
    } else {
      child = _placeholder(theme);
    }
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _placeholder(ThemeData theme) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined,
              color: theme.colorScheme.outline, size: 32),
          const SizedBox(height: 4),
          Text('Foto', style: theme.textTheme.labelSmall),
        ],
      );
}
