import '../../../core/database/app_database.dart';

/// Detail satu pembelian: nota + baris item (dari snapshot).
class PurchaseDetail {
  final Purchase purchase;
  final List<PurchaseItem> items;
  const PurchaseDetail({required this.purchase, required this.items});
}
