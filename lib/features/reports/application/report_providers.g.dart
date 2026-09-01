// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reportRepository)
const reportRepositoryProvider = ReportRepositoryProvider._();

final class ReportRepositoryProvider
    extends
        $FunctionalProvider<
          ReportRepository,
          ReportRepository,
          ReportRepository
        >
    with $Provider<ReportRepository> {
  const ReportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReportRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportRepository create(Ref ref) {
    return reportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportRepository>(value),
    );
  }
}

String _$reportRepositoryHash() => r'736a54099b2dde573a2efa7ed0c6966913b8b0b6';

@ProviderFor(reportExportService)
const reportExportServiceProvider = ReportExportServiceProvider._();

final class ReportExportServiceProvider
    extends
        $FunctionalProvider<
          ReportExportService,
          ReportExportService,
          ReportExportService
        >
    with $Provider<ReportExportService> {
  const ReportExportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportExportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportExportServiceHash();

  @$internal
  @override
  $ProviderElement<ReportExportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReportExportService create(Ref ref) {
    return reportExportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportExportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportExportService>(value),
    );
  }
}

String _$reportExportServiceHash() =>
    r'c6ef9842d1b2e121ede033e412ce07a88dc814b6';

@ProviderFor(reportFileSharer)
const reportFileSharerProvider = ReportFileSharerProvider._();

final class ReportFileSharerProvider
    extends
        $FunctionalProvider<
          ReportFileSharer,
          ReportFileSharer,
          ReportFileSharer
        >
    with $Provider<ReportFileSharer> {
  const ReportFileSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportFileSharerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportFileSharerHash();

  @$internal
  @override
  $ProviderElement<ReportFileSharer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportFileSharer create(Ref ref) {
    return reportFileSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportFileSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportFileSharer>(value),
    );
  }
}

String _$reportFileSharerHash() => r'bc9f46971555a012a7e0fb4142c14076e455c62e';

/// Rentang tanggal aktif untuk dashboard & laporan (default: hari ini, §14).

@ProviderFor(ReportRange)
const reportRangeProvider = ReportRangeProvider._();

/// Rentang tanggal aktif untuk dashboard & laporan (default: hari ini, §14).
final class ReportRangeProvider
    extends $NotifierProvider<ReportRange, ReportDateRange> {
  /// Rentang tanggal aktif untuk dashboard & laporan (default: hari ini, §14).
  const ReportRangeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportRangeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportRangeHash();

  @$internal
  @override
  ReportRange create() => ReportRange();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportDateRange value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportDateRange>(value),
    );
  }
}

String _$reportRangeHash() => r'418ad0c6fec59900ea057c1da645e3637eb875b6';

/// Rentang tanggal aktif untuk dashboard & laporan (default: hari ini, §14).

abstract class _$ReportRange extends $Notifier<ReportDateRange> {
  ReportDateRange build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ReportDateRange, ReportDateRange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReportDateRange, ReportDateRange>,
              ReportDateRange,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
/// dan ekspor. Satu sumber agar konsisten & hemat query.

@ProviderFor(reportBundle)
const reportBundleProvider = ReportBundleFamily._();

/// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
/// dan ekspor. Satu sumber agar konsisten & hemat query.

final class ReportBundleProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReportBundle>,
          ReportBundle,
          FutureOr<ReportBundle>
        >
    with $FutureModifier<ReportBundle>, $FutureProvider<ReportBundle> {
  /// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
  /// dan ekspor. Satu sumber agar konsisten & hemat query.
  const ReportBundleProvider._({
    required ReportBundleFamily super.from,
    required ReportDateRange super.argument,
  }) : super(
         retry: null,
         name: r'reportBundleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reportBundleHash();

  @override
  String toString() {
    return r'reportBundleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReportBundle> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReportBundle> create(Ref ref) {
    final argument = this.argument as ReportDateRange;
    return reportBundle(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportBundleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reportBundleHash() => r'158747a37876049945e1bb92522db66a487ce7d9';

/// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
/// dan ekspor. Satu sumber agar konsisten & hemat query.

final class ReportBundleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReportBundle>, ReportDateRange> {
  const ReportBundleFamily._()
    : super(
        retry: null,
        name: r'reportBundleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
  /// dan ekspor. Satu sumber agar konsisten & hemat query.

  ReportBundleProvider call(ReportDateRange range) =>
      ReportBundleProvider._(argument: range, from: this);

  @override
  String toString() => r'reportBundleProvider';
}

/// Ringkasan transaksi per karyawan untuk [range] (Fase 6).

@ProviderFor(employeeSummary)
const employeeSummaryProvider = EmployeeSummaryFamily._();

/// Ringkasan transaksi per karyawan untuk [range] (Fase 6).

final class EmployeeSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EmployeeSummaryRow>>,
          List<EmployeeSummaryRow>,
          FutureOr<List<EmployeeSummaryRow>>
        >
    with
        $FutureModifier<List<EmployeeSummaryRow>>,
        $FutureProvider<List<EmployeeSummaryRow>> {
  /// Ringkasan transaksi per karyawan untuk [range] (Fase 6).
  const EmployeeSummaryProvider._({
    required EmployeeSummaryFamily super.from,
    required ReportDateRange super.argument,
  }) : super(
         retry: null,
         name: r'employeeSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$employeeSummaryHash();

  @override
  String toString() {
    return r'employeeSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<EmployeeSummaryRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EmployeeSummaryRow>> create(Ref ref) {
    final argument = this.argument as ReportDateRange;
    return employeeSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EmployeeSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$employeeSummaryHash() => r'27b87ab852ef43a97cf42304ee4f38e0886e7487';

/// Ringkasan transaksi per karyawan untuk [range] (Fase 6).

final class EmployeeSummaryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<EmployeeSummaryRow>>,
          ReportDateRange
        > {
  const EmployeeSummaryFamily._()
    : super(
        retry: null,
        name: r'employeeSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Ringkasan transaksi per karyawan untuk [range] (Fase 6).

  EmployeeSummaryProvider call(ReportDateRange range) =>
      EmployeeSummaryProvider._(argument: range, from: this);

  @override
  String toString() => r'employeeSummaryProvider';
}
