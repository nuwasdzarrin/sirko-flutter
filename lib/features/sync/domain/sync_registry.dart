/// Registry tabel sinkronisasi — cermin `sirko-backend/src/db/backup-tables.ts`
/// (lihat SYNC.md §2 & §8). Satu sumber kebenaran untuk pemetaan kolom
/// lokal (snake_case SQLite) ↔ wire (camelCase JSON), kelas idempotency, dan
/// urutan proses (master → header → detail).
///
/// Kolom standar (`id`, `created_at`, `updated_at`, `deleted_at`, `is_dirty`)
/// ditangani generik oleh engine — TIDAK didaftarkan di [SyncTable.cols].
library;

enum SyncColType { text, int, bool, json }

/// Kelas idempotency server: `lww` (mutable, last-write-wins by updatedAt),
/// `append` (ledger immutable), `singleton` (`business`, 1 baris per toko).
enum SyncKind { lww, append, singleton }

class SyncCol {
  final String wire;
  final String db;
  final SyncColType type;
  const SyncCol(this.wire, this.db, [this.type = SyncColType.text]);
}

class SyncTable {
  /// Kunci di `payload.tables` / respons pull.
  final String wire;

  /// Nama tabel SQLite lokal.
  final String local;
  final SyncKind kind;
  final List<SyncCol> cols;
  const SyncTable(this.wire, this.local, this.kind, this.cols);
}

const _i = SyncColType.int;
const _b = SyncColType.bool;

/// Versi **kontrak wire** yang dikirim di `clientInfo.schemaVersion` (SYNC.md
/// §8.2) — bukan versi skema DB lokal.
const syncWireSchemaVersion = 10;

/// Kunci `app_settings` milik **toko** yang ikut tersinkron. Kunci lain
/// (counter invoice, cursor sync, penanda seed katalog, …) khusus perangkat.
const syncedSettingKeys = <String>{
  'allow_negative_stock',
  'require_open_bill',
  'costing_method',
  'default_cash_wallet_id',
};

/// Urutan = urutan proses push (master → header → detail).
const syncTables = <SyncTable>[
  SyncTable('business', 'businesses', SyncKind.singleton, [
    SyncCol('name', 'name'),
    SyncCol('businessType', 'business_type'),
    SyncCol('address', 'address'),
    SyncCol('phone', 'phone'),
    SyncCol('logoPath', 'logo_path'),
    SyncCol('taxEnabled', 'tax_enabled', _b),
    SyncCol('taxPercent', 'tax_percent', _i),
    SyncCol('taxInclusive', 'tax_inclusive', _b),
    SyncCol('roundingMode', 'rounding_mode'),
    SyncCol('currencySymbol', 'currency_symbol'),
  ]),
  SyncTable('users', 'users', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('username', 'username'),
    SyncCol('pinHash', 'pin_hash'),
    SyncCol('role', 'role'),
    SyncCol('permissions', 'permissions', SyncColType.json),
    SyncCol('isActive', 'is_active', _b),
  ]),
  SyncTable('categories', 'categories', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('color', 'color'),
    SyncCol('sortOrder', 'sort_order', _i),
  ]),
  SyncTable('units', 'units', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('isBaseUnit', 'is_base_unit', _b),
  ]),
  SyncTable('customers', 'customers', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('phone', 'phone'),
    SyncCol('address', 'address'),
    SyncCol('birthdate', 'birthdate', _i),
    SyncCol('debtBalance', 'debt_balance', _i),
    SyncCol('note', 'note'),
  ]),
  SyncTable('products', 'products', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('barcode', 'barcode'),
    SyncCol('categoryId', 'category_id'),
    SyncCol('unitId', 'unit_id'),
    SyncCol('costPrice', 'cost_price', _i),
    SyncCol('sellingPrice', 'selling_price', _i),
    SyncCol('stock', 'stock', _i),
    SyncCol('minStock', 'min_stock', _i),
    SyncCol('expiryDate', 'expiry_date', _i),
    SyncCol('imagePath', 'image_path'),
    SyncCol('hasVariants', 'has_variants', _b),
    SyncCol('isActive', 'is_active', _b),
    SyncCol('needsPrice', 'needs_price', _b),
  ]),
  SyncTable('product_variants', 'product_variants', SyncKind.lww, [
    SyncCol('productId', 'product_id'),
    SyncCol('name', 'name'),
    SyncCol('barcode', 'barcode'),
    SyncCol('sellingPrice', 'selling_price', _i),
    SyncCol('costPrice', 'cost_price', _i),
    SyncCol('stock', 'stock', _i),
  ]),
  SyncTable('wholesale_prices', 'wholesale_prices', SyncKind.lww, [
    SyncCol('productId', 'product_id'),
    SyncCol('minQty', 'min_qty', _i),
    SyncCol('price', 'price', _i),
  ]),
  SyncTable('suppliers', 'suppliers', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('phone', 'phone'),
    SyncCol('address', 'address'),
    SyncCol('debtBalance', 'debt_balance', _i),
    SyncCol('note', 'note'),
  ]),
  SyncTable('wallets', 'wallets', SyncKind.lww, [
    SyncCol('name', 'name'),
    SyncCol('balance', 'balance', _i),
    SyncCol('type', 'type'),
  ]),
  SyncTable('app_settings', 'app_settings', SyncKind.lww, [
    SyncCol('key', 'key'),
    SyncCol('value', 'value'),
  ]),
  SyncTable('bills', 'bills', SyncKind.lww, [
    SyncCol('employeeId', 'employee_id'),
    SyncCol('openedAt', 'opened_at', _i),
    SyncCol('closedAt', 'closed_at', _i),
    SyncCol('openingCash', 'opening_cash', _i),
    SyncCol('closingCash', 'closing_cash', _i),
    SyncCol('expectedCash', 'expected_cash', _i),
    SyncCol('cashSalesTotal', 'cash_sales_total', _i),
    SyncCol('variance', 'variance', _i),
    SyncCol('status', 'status'),
    SyncCol('note', 'note'),
  ]),
  SyncTable('transactions', 'transactions', SyncKind.lww, [
    SyncCol('invoiceNo', 'invoice_no'),
    SyncCol('datetime', 'datetime', _i),
    SyncCol('cashierId', 'cashier_id'),
    SyncCol('customerId', 'customer_id'),
    SyncCol('billId', 'bill_id'),
    SyncCol('subtotal', 'subtotal', _i),
    SyncCol('discountTotal', 'discount_total', _i),
    SyncCol('taxTotal', 'tax_total', _i),
    SyncCol('grandTotal', 'grand_total', _i),
    SyncCol('paidTotal', 'paid_total', _i),
    SyncCol('changeTotal', 'change_total', _i),
    SyncCol('roundingAdjustment', 'rounding_adjustment', _i),
    SyncCol('status', 'status'),
    SyncCol('isCredit', 'is_credit', _b),
    SyncCol('note', 'note'),
  ]),
  SyncTable('installments', 'installments', SyncKind.lww, [
    SyncCol('transactionId', 'transaction_id'),
    SyncCol('dueDate', 'due_date', _i),
    SyncCol('amountDue', 'amount_due', _i),
    SyncCol('amountPaid', 'amount_paid', _i),
    SyncCol('status', 'status'),
  ]),
  SyncTable('purchases', 'purchases', SyncKind.lww, [
    SyncCol('refNo', 'ref_no'),
    SyncCol('supplierId', 'supplier_id'),
    SyncCol('datetime', 'datetime', _i),
    SyncCol('subtotal', 'subtotal', _i),
    SyncCol('discountTotal', 'discount_total', _i),
    SyncCol('grandTotal', 'grand_total', _i),
    SyncCol('paidTotal', 'paid_total', _i),
    SyncCol('status', 'status'),
    SyncCol('note', 'note'),
  ]),
  SyncTable('stock_opnames', 'stock_opnames', SyncKind.lww, [
    SyncCol('refNo', 'ref_no'),
    SyncCol('datetime', 'datetime', _i),
    SyncCol('userId', 'user_id'),
    SyncCol('status', 'status'),
    SyncCol('note', 'note'),
  ]),
  // ── Ledger (append-only) ─────────────────────────────────────────────────
  SyncTable('transaction_items', 'transaction_items', SyncKind.append, [
    SyncCol('transactionId', 'transaction_id'),
    SyncCol('productId', 'product_id'),
    SyncCol('variantId', 'variant_id'),
    SyncCol('nameSnapshot', 'name_snapshot'),
    SyncCol('qty', 'qty', _i),
    SyncCol('unitPrice', 'unit_price', _i),
    SyncCol('costPriceSnapshot', 'cost_price_snapshot', _i),
    SyncCol('discount', 'discount', _i),
    SyncCol('lineTotal', 'line_total', _i),
  ]),
  SyncTable('payments', 'payments', SyncKind.append, [
    SyncCol('transactionId', 'transaction_id'),
    SyncCol('method', 'method'),
    SyncCol('amount', 'amount', _i),
    SyncCol('refNote', 'ref_note'),
  ]),
  SyncTable('stock_logs', 'stock_logs', SyncKind.append, [
    SyncCol('productId', 'product_id'),
    SyncCol('variantId', 'variant_id'),
    SyncCol('type', 'type'),
    SyncCol('qtyChange', 'qty_change', _i),
    SyncCol('stockAfter', 'stock_after', _i),
    SyncCol('refType', 'ref_type'),
    SyncCol('refId', 'ref_id'),
    SyncCol('note', 'note'),
  ]),
  SyncTable('wallet_transactions', 'wallet_transactions', SyncKind.append, [
    SyncCol('walletId', 'wallet_id'),
    SyncCol('type', 'type'),
    SyncCol('amount', 'amount', _i),
    SyncCol('targetWalletId', 'target_wallet_id'),
    SyncCol('category', 'category'),
    SyncCol('refType', 'ref_type'),
    SyncCol('refId', 'ref_id'),
    SyncCol('note', 'note'),
    SyncCol('datetime', 'datetime', _i),
  ]),
  SyncTable('credit_payments', 'credit_payments', SyncKind.append, [
    SyncCol('customerId', 'customer_id'),
    SyncCol('transactionId', 'transaction_id'),
    SyncCol('installmentId', 'installment_id'),
    SyncCol('amount', 'amount', _i),
    SyncCol('datetime', 'datetime', _i),
    SyncCol('method', 'method'),
    SyncCol('note', 'note'),
  ]),
  SyncTable('purchase_items', 'purchase_items', SyncKind.append, [
    SyncCol('purchaseId', 'purchase_id'),
    SyncCol('productId', 'product_id'),
    SyncCol('variantId', 'variant_id'),
    SyncCol('nameSnapshot', 'name_snapshot'),
    SyncCol('qty', 'qty', _i),
    SyncCol('costPrice', 'cost_price', _i),
    SyncCol('lineTotal', 'line_total', _i),
  ]),
  SyncTable('stock_opname_items', 'stock_opname_items', SyncKind.append, [
    SyncCol('opnameId', 'opname_id'),
    SyncCol('productId', 'product_id'),
    SyncCol('variantId', 'variant_id'),
    SyncCol('nameSnapshot', 'name_snapshot'),
    SyncCol('systemQty', 'system_qty', _i),
    SyncCol('physicalQty', 'physical_qty', _i),
    SyncCol('diff', 'diff', _i),
  ]),
];

final syncTableByWire = {for (final t in syncTables) t.wire: t};
