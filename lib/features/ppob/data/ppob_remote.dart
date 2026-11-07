import '../../cloud/data/cloud_api_client.dart';
import 'ppob_models.dart';

/// Endpoint PPOB & Poin (KONTRAK-API-ppob-app.md + akun §6–§7). Online-only;
/// semua lewat [CloudApiClient] (Bearer + refresh 401).
abstract class PpobRemote {
  Future<PpobStatus> status();
  Future<List<PpobProduct>> products(PpobCategory category,
      {String? customerNo});
  Future<PpobPricing> pricing();
  Future<({PpobPricing pricing, List<PricingWarning> warnings})> savePricing(
      PpobPricing pricing);
  Future<PointsSummary> points();
  Future<({List<LedgerItem> items, String? nextCursor})> ledger(
      {String? cursor});
  Future<Topup> createTopup(int amount);
  Future<Topup> topup(String id);
  Future<Topup> cancelTopup(String id);
  Future<({bool ok, String? name, String? segmentPower, String? message})>
      plnInquiry(String meterNo);
  Future<PpobOrder> createOrder({
    required String clientRef,
    required String productId,
    required String customerNo,
    String? notifyEmail,
    Duration? timeout,
  });
  Future<PpobOrder> order(String id);
  Future<({List<PpobOrder> items, String? nextCursor})> orders(
      {String? cursor});
}

class HttpPpobRemote implements PpobRemote {
  final CloudApiClient _api;
  HttpPpobRemote(this._api);

  Object? _data(Map<String, dynamic> res) => res['data'];
  Map<String, Object?> _map(Map<String, dynamic> res) =>
      (_data(res) as Map).cast<String, Object?>();
  String? _next(Map<String, dynamic> res) =>
      ((res['meta'] as Map?)?['nextCursor']) as String?;

  @override
  Future<PpobStatus> status() async =>
      PpobStatus.fromJson(_map(await _api.getJson('/v1/ppob/status')));

  @override
  Future<List<PpobProduct>> products(PpobCategory category,
      {String? customerNo}) async {
    final res = await _api.getJson('/v1/ppob/products', query: {
      'category': category.key,
      if (customerNo != null && customerNo.isNotEmpty) 'customerNo': customerNo,
    });
    return [
      for (final p in (_data(res) as List?) ?? const [])
        if (p is Map) PpobProduct.fromJson(p.cast<String, Object?>()),
    ];
  }

  @override
  Future<PpobPricing> pricing() async =>
      PpobPricing.fromJson(_map(await _api.getJson('/v1/ppob/pricing')));

  @override
  Future<({PpobPricing pricing, List<PricingWarning> warnings})> savePricing(
      PpobPricing pricing) async {
    final d = _map(await _api.putJson('/v1/ppob/pricing', pricing.toJson()));
    return (
      pricing: PpobPricing.fromJson(d),
      warnings: [
        for (final w in (d['warnings'] as List?) ?? const [])
          if (w is Map)
            PricingWarning(w['productId'] as String,
                (w['message'] as String?) ?? ''),
      ],
    );
  }

  @override
  Future<PointsSummary> points() async =>
      PointsSummary.fromJson(_map(await _api.getJson('/v1/points')));

  @override
  Future<({List<LedgerItem> items, String? nextCursor})> ledger(
      {String? cursor}) async {
    final res = await _api.getJson('/v1/points/ledger',
        query: {if (cursor != null) 'cursor': cursor});
    return (
      items: [
        for (final l in (_data(res) as List?) ?? const [])
          if (l is Map) LedgerItem.fromJson(l.cast<String, Object?>()),
      ],
      nextCursor: _next(res),
    );
  }

  @override
  Future<Topup> createTopup(int amount) async => Topup.fromJson(
      _map(await _api.postJson('/v1/points/topups', {'amount': amount})));

  @override
  Future<Topup> topup(String id) async =>
      Topup.fromJson(_map(await _api.getJson('/v1/points/topups/$id')));

  @override
  Future<Topup> cancelTopup(String id) async => Topup.fromJson(
      _map(await _api.postJson('/v1/points/topups/$id/cancel', const {})));

  @override
  Future<({bool ok, String? name, String? segmentPower, String? message})>
      plnInquiry(String meterNo) async {
    final d = _map(await _api
        .postJson('/v1/ppob/pln/inquiry', {'meterNo': meterNo}));
    return (
      ok: (d['ok'] as bool?) ?? false,
      name: d['name'] as String?,
      segmentPower: d['segmentPower'] as String?,
      message: d['message'] as String?,
    );
  }

  @override
  Future<PpobOrder> createOrder({
    required String clientRef,
    required String productId,
    required String customerNo,
    String? notifyEmail,
    Duration? timeout,
  }) async =>
      PpobOrder.fromJson(_map(await _api.postJson(
          '/v1/ppob/orders',
          {
            'clientRef': clientRef,
            'productId': productId,
            'customerNo': customerNo,
            if (notifyEmail != null && notifyEmail.isNotEmpty)
              'notifyEmail': notifyEmail,
          },
          timeout: timeout)));

  @override
  Future<PpobOrder> order(String id) async =>
      PpobOrder.fromJson(_map(await _api.getJson('/v1/ppob/orders/$id')));

  @override
  Future<({List<PpobOrder> items, String? nextCursor})> orders(
      {String? cursor}) async {
    final res = await _api.getJson('/v1/ppob/orders',
        query: {if (cursor != null) 'cursor': cursor});
    return (
      items: [
        for (final o in (_data(res) as List?) ?? const [])
          if (o is Map) PpobOrder.fromJson(o.cast<String, Object?>()),
      ],
      nextCursor: _next(res),
    );
  }
}
