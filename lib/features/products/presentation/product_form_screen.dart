import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../application/catalog_providers.dart';
import '../application/product_providers.dart';
import 'barcode_scanner_screen.dart';
import 'category_management_screen.dart';
import 'unit_management_screen.dart';
import 'variant_management_screen.dart';
import 'wholesale_price_screen.dart';
import 'widgets/rupiah_field.dart';

/// Form tambah/edit produk. [existing] null = tambah baru.
class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? existing;
  const ProductFormScreen({super.key, this.existing});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final RupiahEditingController _costController;
  late final RupiahEditingController _sellingController;

  String? _categoryId;
  String? _unitId;
  String? _imagePath;
  int? _expiryDate;
  bool _hasVariants = false;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _stockController =
        TextEditingController(text: (p?.stock ?? 0).toString());
    _minStockController =
        TextEditingController(text: p?.minStock?.toString() ?? '');
    _costController = RupiahEditingController(initial: p?.costPrice ?? 0);
    _sellingController = RupiahEditingController(initial: p?.sellingPrice ?? 0);
    _categoryId = p?.categoryId;
    _unitId = p?.unitId;
    _imagePath = p?.imagePath;
    _expiryDate = p?.expiryDate;
    _hasVariants = p?.hasVariants ?? false;
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final initial = _expiryDate == null
        ? now
        : DateTimeUtils.toLocal(_expiryDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _expiryDate = DateTimeUtils.startOfDayLocal(picked));
    }
  }

  static String _formatExpiry(int epochMs) {
    final d = DateTimeUtils.toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      _barcodeController.text = code;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final stored =
        await ref.read(productImageStorageProvider).persist(picked.path);
    if (mounted) setState(() => _imagePath = stored);
  }

  Future<void> _chooseImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Hapus foto'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = ref.read(productRepositoryProvider);
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final minStockText = _minStockController.text.trim();
    final args = {
      'name': name,
      'barcode': barcode.isEmpty ? null : barcode,
      'categoryId': _categoryId,
      'unitId': _unitId,
      'costPrice': _costController.rupiah,
      'sellingPrice': _sellingController.rupiah,
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'minStock': minStockText.isEmpty ? null : int.tryParse(minStockText),
      'imagePath': _imagePath,
      'expiryDate': _expiryDate,
      'hasVariants': _hasVariants,
    };
    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: args['name'] as String,
          barcode: args['barcode'] as String?,
          categoryId: args['categoryId'] as String?,
          unitId: args['unitId'] as String?,
          costPrice: args['costPrice'] as int,
          sellingPrice: args['sellingPrice'] as int,
          stock: args['stock'] as int,
          minStock: args['minStock'] as int?,
          imagePath: args['imagePath'] as String?,
          expiryDate: args['expiryDate'] as int?,
          hasVariants: args['hasVariants'] as bool,
        );
      } else {
        await repo.create(
          name: args['name'] as String,
          barcode: args['barcode'] as String?,
          categoryId: args['categoryId'] as String?,
          unitId: args['unitId'] as String?,
          costPrice: args['costPrice'] as int,
          sellingPrice: args['sellingPrice'] as int,
          stock: args['stock'] as int,
          minStock: args['minStock'] as int?,
          imagePath: args['imagePath'] as String?,
          expiryDate: args['expiryDate'] as int?,
          hasVariants: args['hasVariants'] as bool,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan produk: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoryListProvider).asData?.value ?? const [];
    final units = ref.watch(unitListProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Produk' : 'Produk Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PhotoPicker(imagePath: _imagePath, onTap: _chooseImageSource),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('product_name_field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama produk',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama produk wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Barcode (opsional)',
                prefixIcon: const Icon(Icons.qr_code_2_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Scan barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CategoryDropdown(
              categories: categories,
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            _UnitDropdown(
              units: units,
              value: _unitId,
              onChanged: (v) => setState(() => _unitId = v),
            ),
            const SizedBox(height: 16),
            RupiahField(
                controller: _costController,
                label: 'Harga modal',
                icon: Icons.payments_outlined),
            const SizedBox(height: 16),
            RupiahField(
                controller: _sellingController,
                label: 'Harga jual',
                icon: Icons.sell_outlined),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok awal',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok min.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Tanggal kadaluarsa'),
              subtitle: Text(_expiryDate == null
                  ? 'Tidak diset'
                  : _formatExpiry(_expiryDate!)),
              trailing: _expiryDate == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiryDate = null),
                    ),
              onTap: _pickExpiry,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.style_outlined),
              title: const Text('Produk bervarian'),
              subtitle: const Text(
                  'Stok & harga dikelola per varian (mis. warna/ukuran).'),
              value: _hasVariants,
              onChanged: (v) => setState(() => _hasVariants = v),
            ),
            if (_isEdit) ...[
              const Divider(height: 24),
              if (_hasVariants)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VariantManagementScreen(
                        productId: widget.existing!.id,
                        productName: _nameController.text.trim(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Kelola Varian'),
                ),
              if (_hasVariants) const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WholesalePriceScreen(
                      productId: widget.existing!.id,
                      productName: _nameController.text.trim(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Harga Grosir'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Simpan dulu untuk mengelola varian & harga grosir.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('product_save_button'),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Produk'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTap;
  const _PhotoPicker({required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            image: hasImage
                ? DecorationImage(
                    image: FileImage(File(imagePath!)), fit: BoxFit.cover)
                : null,
          ),
          child: hasImage
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text('Foto', style: theme.textTheme.labelSmall),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Jaga nilai valid bila kategori terpilih sudah dihapus.
    final safeValue =
        categories.any((c) => c.id == value) ? value : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: safeValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: onChanged,
          ),
        ),
        IconButton(
          tooltip: 'Kelola kategori',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const CategoryManagementScreen()),
          ),
        ),
      ],
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final List<Unit> units;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _UnitDropdown({
    required this.units,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = units.any((u) => u.id == value) ? value : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: safeValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Satuan',
              prefixIcon: Icon(Icons.straighten_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tanpa satuan')),
              for (final u in units)
                DropdownMenuItem(value: u.id, child: Text(u.name)),
            ],
            onChanged: onChanged,
          ),
        ),
        IconButton(
          tooltip: 'Kelola satuan',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UnitManagementScreen()),
          ),
        ),
      ],
    );
  }
}
