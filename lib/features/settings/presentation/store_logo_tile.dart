import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../onboarding/application/onboarding_providers.dart';
import '../application/store_logo_providers.dart';

/// Pengaturan logo struk (branding struk — fitur paket Juragan).
/// Logo diolah jadi hitam-putih agar tajam di printer thermal.
class StoreLogoTile extends ConsumerStatefulWidget {
  const StoreLogoTile({super.key});

  @override
  ConsumerState<StoreLogoTile> createState() => _StoreLogoTileState();
}

class _StoreLogoTileState extends ConsumerState<StoreLogoTile> {
  bool _busy = false;

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    final storage = ref.read(storeLogoStorageProvider);
    final repo = ref.read(businessRepositoryProvider);
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final old = (await repo.getBusiness())?.logoPath;
      final path = await storage.persist(picked.path);
      await repo.setLogoPath(path);
      if (old != path) await storage.deleteIfExists(old);
      ref.invalidate(receiptLogoProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Logo struk disimpan.')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final repo = ref.read(businessRepositoryProvider);
    final old = (await repo.getBusiness())?.logoPath;
    await repo.setLogoPath(null);
    await ref.read(storeLogoStorageProvider).deleteIfExists(old);
    ref.invalidate(receiptLogoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final logo = ref.watch(receiptLogoProvider).asData?.value;
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: logo == null
            ? const Icon(Icons.image_outlined, size: 32)
            : Image.memory(logo, fit: BoxFit.contain),
      ),
      title: const Text('Logo di struk'),
      subtitle: Text(logo == null
          ? 'Belum ada. Tampil di atas nama warung pada struk.'
          : 'Tampil di atas nama warung pada struk.'),
      trailing: _busy
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator())
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logo != null)
                  IconButton(
                    tooltip: 'Hapus logo',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _remove,
                  ),
                IconButton(
                  tooltip: logo == null ? 'Pilih logo' : 'Ganti logo',
                  icon: const Icon(Icons.upload_outlined),
                  onPressed: _pick,
                ),
              ],
            ),
    );
  }
}
