import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/store_registry.dart';
import '../../../core/network/cloud_api.dart';
import '../../subscription/application/plan_providers.dart';
import '../../subscription/domain/plan.dart';
import '../../subscription/presentation/juragan_screen.dart';
import '../application/store_switcher.dart';
import '../data/store_remote.dart';
import 'combined_report_screen.dart';
import 'cross_store_screen.dart';

/// "Toko Saya" (paket Juragan, multi-cabang): pilih toko yang dibuka di HP
/// ini, tambah cabang, dan laporan gabungan.
class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(storeSwitcherProvider).refreshMe();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Jalankan [action] dengan dialog progres; error paket → layar langganan.
  Future<void> _run(
      Future<void> Function(void Function(SwitchStep)) action) async {
    final step = ValueNotifier<SwitchStep>(SwitchStep.pushing);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<SwitchStep>(
            valueListenable: step,
            builder: (_, s, __) => Row(children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(_stepLabel(s))),
            ]),
          ),
        ),
      ),
    );
    try {
      await action((s) => step.value = s);
      nav.pop(); // tutup dialog progres
      // Sesi sudah berganti toko → kembali ke akar (router minta PIN).
      nav.popUntil((r) => r.isFirst);
    } on CloudException catch (e) {
      nav.pop();
      if (e.isPlanError && mounted) {
        openJuraganScreen(context, locked: PlanFeature.multiStore);
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  static String _stepLabel(SwitchStep s) => switch (s) {
        SwitchStep.pushing => 'Mengirim data toko ini ke cloud…',
        SwitchStep.switching => 'Menghubungi server…',
        SwitchStep.opening => 'Membuka toko…',
        SwitchStep.pulling => 'Mengambil data toko dari cloud…',
        SwitchStep.done => 'Selesai',
      };

  Future<void> _switch(CloudBusiness b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Buka ${b.name}?'),
        content: const Text('Data toko yang sekarang dikirim ke cloud dulu, '
            'lalu kamu perlu masuk dengan PIN pengguna toko tujuan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Buka')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run((onStep) => ref
        .read(storeSwitcherProvider)
        .switchTo(b.id, onStep: onStep));
  }

  Future<void> _addStore() async {
    if (!requireFeature(context, ref, PlanFeature.multiStore)) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tambah toko cabang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Nama toko', hintText: 'mis. Warung Cabang Pasar'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, controller.text.trim()),
              child: const Text('Buat & buka')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await _run((onStep) =>
        ref.read(storeSwitcherProvider).createStore(name, onStep: onStep));
  }

  @override
  Widget build(BuildContext context) {
    final businesses = ref.watch(cloudBusinessesProvider);
    final activeId = ref.watch(storeRegistryProvider).active.businessId;
    final plan = ref.watch(planProvider);
    final canMulti = ref.watch(featureAllowedProvider(PlanFeature.multiStore));

    return Scaffold(
      appBar: AppBar(title: const Text('Toko Saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStore,
        icon: Icon(canMulti ? Icons.add_business_outlined : Icons.lock_outline),
        label: const Text('Tambah cabang'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Daftar toko belum bisa dimuat'),
                subtitle: Text(_error!),
              ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(plan.isJuragan ? 'Paket Juragan' : 'Paket Warung'),
              subtitle: Text('${businesses.length} dari ${plan.maxStores} toko'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openJuraganScreen(context),
            ),
            ListTile(
              leading: const Icon(Icons.query_stats_outlined),
              title: const Text('Laporan gabungan semua toko'),
              trailing: Icon(canMulti ? Icons.chevron_right : Icons.lock_outline),
              onTap: () {
                if (!requireFeature(context, ref, PlanFeature.multiStore)) {
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CombinedReportScreen()));
              },
            ),
            for (final (mode, icon, title) in [
              (CrossStoreMode.sendStock, Icons.local_shipping_outlined,
                  'Kirim stok ke cabang'),
              (CrossStoreMode.copyProducts, Icons.copy_all_outlined,
                  'Salin produk ke cabang'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                trailing:
                    Icon(canMulti ? Icons.chevron_right : Icons.lock_outline),
                onTap: () {
                  if (!requireFeature(context, ref, PlanFeature.multiStore)) {
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CrossStoreScreen(mode: mode)));
                },
              ),
            const Divider(),
            for (final b in businesses)
              ListTile(
                leading: Icon(b.id == activeId
                    ? Icons.storefront
                    : Icons.storefront_outlined),
                title: Text(b.name),
                subtitle: Text(b.id == activeId
                    ? 'Sedang dibuka di HP ini'
                    : 'Ketuk untuk membuka'),
                trailing: b.id == activeId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: b.id == activeId ? null : () => _switch(b),
              ),
          ],
        ),
      ),
    );
  }
}
