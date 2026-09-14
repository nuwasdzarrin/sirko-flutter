import '../../cloud/data/cloud_api_client.dart';
import '../domain/contribution.dart';

/// Kontribusi katalog crowdsource (API.md §2b). Toko biasa boleh **mengusulkan**
/// produk baru / perbaikan → antre `pending` → di-review admin.
class CloudContributionRepository {
  final CloudApiClient _api;
  const CloudContributionRepository(this._api);

  /// Kirim usulan. Return id + status (`pending`).
  Future<ContributionResult> submit(ContributionInput input) async {
    final json =
        await _api.postJson('/v1/catalog/contributions', input.toBody());
    final d = json['data'] as Map<String, dynamic>;
    return ContributionResult(
      id: (d['id'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'pending',
    );
  }

  /// Daftar **usulan toko saya** (+ status). Filter opsional `status`.
  Future<List<ContributionItem>> myContributions({String? status}) async {
    final json = await _api.getJson('/v1/catalog/contributions', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': '50',
    });
    return (json['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ContributionItem.fromJson)
        .toList();
  }
}
