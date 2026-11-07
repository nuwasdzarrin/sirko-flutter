import '../../cloud/data/cloud_api_client.dart';
import '../domain/cross_store.dart';

/// Toko yang bisa dibuka akun ini (`businesses[]`, KONTRAK §1.2).
class CloudBusiness {
  final String id;
  final String name;
  final String role;
  const CloudBusiness({required this.id, required this.name, required this.role});

  factory CloudBusiness.fromJson(Map<String, Object?> j) => CloudBusiness(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Toko',
        role: (j['role'] as String?) ?? 'owner',
      );
}

/// Bentuk respons login / switch-business / POST businesses (identik, KONTRAK §2).
class SessionPayload {
  final String accessToken;
  final String refreshToken;

  /// Toko sesi ini; null = **sesi akun** (belum punya toko, KONTRAK akun §2).
  final String? businessId;
  final String? businessName;
  final String? businessType;
  final List<CloudBusiness> businesses;
  final Map<String, Object?>? plan;

  /// `account` & `offlineAuth` (KONTRAK akun §2) — mentah, diurai di fitur akun.
  final Map<String, Object?>? account;
  final Map<String, Object?>? offlineAuth;

  const SessionPayload({
    required this.accessToken,
    required this.refreshToken,
    this.businessId,
    this.businessName,
    this.businessType,
    required this.businesses,
    this.plan,
    this.account,
    this.offlineAuth,
  });

  bool get hasStore => businessId != null;

  factory SessionPayload.fromJson(Map<String, Object?> d) => SessionPayload(
        accessToken: d['accessToken'] as String,
        refreshToken: d['refreshToken'] as String,
        businessId: ((d['user'] as Map?)?['businessId'] ??
            (d['business'] as Map?)?['id']) as String?,
        businessName: (d['business'] as Map?)?['name'] as String?,
        businessType: (d['business'] as Map?)?['businessType'] as String?,
        businesses: _businesses(d['businesses']),
        plan: (d['plan'] as Map?)?.cast<String, Object?>(),
        account: (d['account'] as Map?)?.cast<String, Object?>(),
        offlineAuth: (d['offlineAuth'] as Map?)?.cast<String, Object?>(),
      );
}

/// `GET /v1/me` (KONTRAK akun §3.8).
class MeInfo {
  final List<CloudBusiness> businesses;
  final Map<String, Object?>? plan;
  final Map<String, Object?>? account;
  final Map<String, Object?>? offlineAuth;
  const MeInfo(
      {required this.businesses, this.plan, this.account, this.offlineAuth});
}

List<CloudBusiness> _businesses(Object? v) => [
      for (final e in (v as List?) ?? const [])
        if (e is Map) CloudBusiness.fromJson(e.cast<String, Object?>()),
    ];

/// Satu toko di laporan gabungan (`GET /v1/juragan/reports/summary`).
class StoreSummary {
  final String businessId;
  final String name;
  final int txCount;
  final int omzet;
  final int grossProfit;
  final int receivables;
  final int cashBalance;

  const StoreSummary({
    required this.businessId,
    required this.name,
    required this.txCount,
    required this.omzet,
    required this.grossProfit,
    required this.receivables,
    required this.cashBalance,
  });

  factory StoreSummary.fromJson(Map<String, Object?> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return StoreSummary(
      businessId: (j['businessId'] as String?) ?? '',
      name: (j['name'] as String?) ?? 'Total',
      txCount: n('txCount'),
      omzet: n('omzet'),
      grossProfit: n('grossProfit'),
      receivables: n('receivables'),
      cashBalance: n('cashBalance'),
    );
  }
}

class CombinedReport {
  final String from;
  final String to;
  final List<StoreSummary> stores;
  final StoreSummary total;
  const CombinedReport(
      {required this.from,
      required this.to,
      required this.stores,
      required this.total});
}

/// Endpoint multi-toko & lintas-toko (KONTRAK §2, prompt backend §4).
abstract class StoreRemote {
  Future<MeInfo> me();
  Future<SessionPayload> switchBusiness(String businessId);
  Future<SessionPayload> createBusiness(String name, {String? businessType});
  Future<CombinedReport> combinedReport(String preset);

  /// Pasangan produk yang sudah tertaut [fromBusinessId] → [toBusinessId].
  Future<List<ProductLink>> productLinks(
      String fromBusinessId, String toBusinessId);

  /// Salin produk ke toko tujuan (tanpa duplikat; stok salinan 0).
  Future<CopyResult> copyProducts(
      String fromBusinessId, String toBusinessId, List<String> productIds);

  /// Kirim stok antar-toko; return id transfer.
  Future<String> stockTransfer(String fromBusinessId, String toBusinessId,
      List<TransferLine> lines,
      {String? note});
}

class HttpStoreRemote implements StoreRemote {
  final CloudApiClient _api;
  HttpStoreRemote(this._api);

  Map<String, Object?> _data(Map<String, dynamic> res) =>
      ((res['data'] ?? res) as Map).cast<String, Object?>();

  @override
  Future<MeInfo> me() async {
    final d = _data(await _api.getJson('/v1/me'));
    return MeInfo(
      businesses: _businesses(d['businesses']),
      plan: (d['plan'] as Map?)?.cast<String, Object?>(),
      account: (d['account'] as Map?)?.cast<String, Object?>(),
      offlineAuth: (d['offlineAuth'] as Map?)?.cast<String, Object?>(),
    );
  }

  @override
  Future<SessionPayload> switchBusiness(String businessId) async =>
      SessionPayload.fromJson(_data(await _api.postJson(
          '/v1/auth/switch-business', {'businessId': businessId})));

  @override
  Future<SessionPayload> createBusiness(String name,
          {String? businessType}) async =>
      SessionPayload.fromJson(_data(await _api.postJson('/v1/businesses', {
        'name': name,
        if (businessType != null && businessType.isNotEmpty)
          'businessType': businessType,
      })));

  @override
  Future<CombinedReport> combinedReport(String preset) async {
    final d = _data(await _api
        .getJson('/v1/juragan/reports/summary', query: {'preset': preset}));
    final range = (d['range'] as Map?) ?? const {};
    return CombinedReport(
      from: (range['from'] as String?) ?? '',
      to: (range['to'] as String?) ?? '',
      stores: [
        for (final s in (d['stores'] as List?) ?? const [])
          if (s is Map) StoreSummary.fromJson(s.cast<String, Object?>()),
      ],
      total: StoreSummary.fromJson(
          ((d['total'] as Map?) ?? const {}).cast<String, Object?>()),
    );
  }

  @override
  Future<List<ProductLink>> productLinks(
      String fromBusinessId, String toBusinessId) async {
    final d = _data(await _api.getJson('/v1/juragan/product-links', query: {
      'fromBusinessId': fromBusinessId,
      'toBusinessId': toBusinessId,
    }));
    return [
      for (final l in (d['links'] as List?) ?? const [])
        if (l is Map) ProductLink.fromJson(l.cast<String, Object?>()),
    ];
  }

  @override
  Future<CopyResult> copyProducts(String fromBusinessId, String toBusinessId,
          List<String> productIds) async =>
      CopyResult.fromJson(
          _data(await _api.postJson('/v1/juragan/copy-products', {
        'fromBusinessId': fromBusinessId,
        'toBusinessId': toBusinessId,
        'productIds': productIds,
      })));

  @override
  Future<String> stockTransfer(
      String fromBusinessId, String toBusinessId, List<TransferLine> lines,
      {String? note}) async {
    final d = _data(await _api.postJson('/v1/juragan/stock-transfers', {
      'fromBusinessId': fromBusinessId,
      'toBusinessId': toBusinessId,
      'lines': [for (final l in lines) l.toJson()],
      if (note != null && note.isNotEmpty) 'note': note,
    }));
    return (d['transferId'] as String?) ?? '';
  }
}
