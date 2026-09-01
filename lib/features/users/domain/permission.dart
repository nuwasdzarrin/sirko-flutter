/// Daftar permission RBAC (spec 02-data-model — "Permission constants").
///
/// Nama enum **harus persis** dengan konstanta spec: dipakai sebagai kunci saat
/// menyimpan/membaca izin `custom` (JSON array of `.name`). Owner selalu punya
/// semua permission (§13) — lihat [PermissionResolver].
enum Permission {
  dashboardAccess,
  productManagement,
  addProduct,
  variantManagement,
  customerManagement,
  transactionList,
  transactionUpdate,
  transactionExport,
  orderManagement,
  orderList,
  creditList,
  walletView,
  walletManagement,
  deleteClosedBill,
  employeeSummary,
  notificationSetting,
  settingCompany,
  recycleBin,
  userService,
  addUser,
  administrator,
}

/// Label ramah bahasa Indonesia untuk editor permission (role `custom`).
extension PermissionLabel on Permission {
  String get label => switch (this) {
        Permission.dashboardAccess => 'Akses dashboard',
        Permission.productManagement => 'Kelola produk',
        Permission.addProduct => 'Tambah produk',
        Permission.variantManagement => 'Kelola varian',
        Permission.customerManagement => 'Kelola pelanggan',
        Permission.transactionList => 'Kasir & riwayat transaksi',
        Permission.transactionUpdate => 'Ubah/void transaksi',
        Permission.transactionExport => 'Ekspor & laporan',
        Permission.orderManagement => 'Kelola order',
        Permission.orderList => 'Daftar order',
        Permission.creditList => 'Daftar hutang/piutang',
        Permission.walletView => 'Lihat kas/wallet',
        Permission.walletManagement => 'Kelola kas/wallet',
        Permission.deleteClosedBill => 'Hapus bill yang sudah ditutup',
        Permission.employeeSummary => 'Ringkasan karyawan',
        Permission.notificationSetting => 'Pengaturan notifikasi',
        Permission.settingCompany => 'Pengaturan toko',
        Permission.recycleBin => 'Recycle Bin',
        Permission.userService => 'Kelola karyawan',
        Permission.addUser => 'Tambah karyawan',
        Permission.administrator => 'Administrator',
      };
}
