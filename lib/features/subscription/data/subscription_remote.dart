import '../../cloud/data/cloud_api_client.dart';
import '../domain/plan.dart';

/// Harga satu periode paket (`GET /v1/plans`).
class PlanPrice {
  final PlanPeriod period;
  final int amount;
  final int maxStores;
  const PlanPrice(
      {required this.period, required this.amount, required this.maxStores});
}

/// Instruksi bayar (QRIS statis + rekening, diatur admin).
class PaymentInstructions {
  final String? qrisUrl;
  final String? bankName;
  final String? accountNo;
  final String? accountName;
  final String? note;
  const PaymentInstructions(
      {this.qrisUrl,
      this.bankName,
      this.accountNo,
      this.accountName,
      this.note});

  factory PaymentInstructions.fromJson(Map<String, Object?>? j) =>
      PaymentInstructions(
        qrisUrl: j?['qrisUrl'] as String?,
        bankName: j?['bankName'] as String?,
        accountNo: j?['accountNo'] as String?,
        accountName: j?['accountName'] as String?,
        note: j?['note'] as String?,
      );
}

class PlanCatalog {
  final List<PlanPrice> prices;
  final PaymentInstructions payment;
  const PlanCatalog({required this.prices, required this.payment});

  /// Harga keputusan pemilik (J2/J9) — dipakai bila server belum menyediakan
  /// `/v1/plans` atau sedang offline. Server tetap sumber kebenaran saat bayar.
  static const fallback = PlanCatalog(prices: [
    PlanPrice(period: PlanPeriod.monthly, amount: 49000, maxStores: 3),
    PlanPrice(period: PlanPeriod.yearly, amount: 499000, maxStores: 3),
  ], payment: PaymentInstructions());

  PlanPrice? priceFor(PlanPeriod p) {
    for (final x in prices) {
      if (x.period == p) return x;
    }
    return null;
  }
}

enum CheckoutStatus { pending, confirmed, rejected, expired }

/// Permintaan bayar (`POST /v1/plan/checkout`): bayar **persis** [amount]
/// (harga + [uniqueCode]) sebelum [expiresAt].
class Checkout {
  final String id;
  final PlanPeriod period;
  final int amount;
  final int uniqueCode;
  final int expiresAt;
  final String? qrisUrl;
  final CheckoutStatus status;
  final String? note;

  /// `plan` terbaru bila [status] = confirmed.
  final Map<String, Object?>? plan;

  const Checkout({
    required this.id,
    required this.period,
    required this.amount,
    required this.uniqueCode,
    required this.expiresAt,
    this.qrisUrl,
    this.status = CheckoutStatus.pending,
    this.note,
    this.plan,
  });

  factory Checkout.fromJson(Map<String, Object?> j, {PlanPeriod? period}) =>
      Checkout(
        id: j['id'] as String,
        period: _period(j['period']) ?? period ?? PlanPeriod.monthly,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        uniqueCode: (j['uniqueCode'] as num?)?.toInt() ?? 0,
        expiresAt: (j['expiresAt'] as num?)?.toInt() ?? 0,
        qrisUrl: j['qrisUrl'] as String?,
        status: switch (j['status']) {
          'confirmed' => CheckoutStatus.confirmed,
          'rejected' => CheckoutStatus.rejected,
          'expired' => CheckoutStatus.expired,
          _ => CheckoutStatus.pending,
        },
        note: j['note'] as String?,
        plan: (j['plan'] as Map?)?.cast<String, Object?>(),
      );
}

PlanPeriod? _period(Object? v) => switch (v) {
      'monthly' => PlanPeriod.monthly,
      'yearly' => PlanPeriod.yearly,
      _ => null,
    };

/// Endpoint langganan (JURAGAN.md §3.3). Abstrak agar UI bisa diuji dengan
/// server palsu.
abstract class SubscriptionRemote {
  Future<PlanCatalog> catalog();
  Future<Checkout> checkout(PlanPeriod period);
  Future<Checkout> status(String checkoutId);
}

class HttpSubscriptionRemote implements SubscriptionRemote {
  final CloudApiClient _api;
  HttpSubscriptionRemote(this._api);

  Map<String, Object?> _data(Map<String, dynamic> res) =>
      ((res['data'] ?? res) as Map).cast<String, Object?>();

  @override
  Future<PlanCatalog> catalog() async {
    final d = _data(await _api.getJson('/v1/plans'));
    final list = (d['prices'] ?? d['plans']) as List? ?? const [];
    final prices = <PlanPrice>[
      for (final e in list.whereType<Map>())
        if (e['plan'] == null || e['plan'] == 'juragan')
          if (_period(e['period']) case final p?)
            PlanPrice(
              period: p,
              amount: (e['amount'] as num).toInt(),
              maxStores: (e['maxStores'] as num?)?.toInt() ?? 3,
            ),
    ];
    return PlanCatalog(
      prices: prices.isEmpty ? PlanCatalog.fallback.prices : prices,
      payment: PaymentInstructions.fromJson(
          (d['payment'] as Map?)?.cast<String, Object?>() ??
              {'qrisUrl': d['qrisUrl']}),
    );
  }

  @override
  Future<Checkout> checkout(PlanPeriod period) async => Checkout.fromJson(
      _data(await _api.postJson('/v1/plan/checkout', {'period': period.name})),
      period: period);

  @override
  Future<Checkout> status(String checkoutId) async => Checkout.fromJson(
      _data(await _api.getJson('/v1/plan/checkout/$checkoutId')));
}
