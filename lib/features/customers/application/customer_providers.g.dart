// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerRepository)
const customerRepositoryProvider = CustomerRepositoryProvider._();

final class CustomerRepositoryProvider
    extends
        $FunctionalProvider<
          CustomerRepository,
          CustomerRepository,
          CustomerRepository
        >
    with $Provider<CustomerRepository> {
  const CustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerRepositoryHash();

  @$internal
  @override
  $ProviderElement<CustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerRepository create(Ref ref) {
    return customerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerRepository>(value),
    );
  }
}

String _$customerRepositoryHash() =>
    r'04260ff816e79d6ae43f2391dd3542b06647176c';

@ProviderFor(creditRepository)
const creditRepositoryProvider = CreditRepositoryProvider._();

final class CreditRepositoryProvider
    extends
        $FunctionalProvider<
          CreditRepository,
          CreditRepository,
          CreditRepository
        >
    with $Provider<CreditRepository> {
  const CreditRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditRepositoryHash();

  @$internal
  @override
  $ProviderElement<CreditRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreditRepository create(Ref ref) {
    return creditRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreditRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreditRepository>(value),
    );
  }
}

String _$creditRepositoryHash() => r'4939d9152bb4fa9c6fd01258076c909abf7e2ef0';

@ProviderFor(contactImportService)
const contactImportServiceProvider = ContactImportServiceProvider._();

final class ContactImportServiceProvider
    extends
        $FunctionalProvider<
          ContactImportService,
          ContactImportService,
          ContactImportService
        >
    with $Provider<ContactImportService> {
  const ContactImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactImportServiceHash();

  @$internal
  @override
  $ProviderElement<ContactImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContactImportService create(Ref ref) {
    return contactImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactImportService>(value),
    );
  }
}

String _$contactImportServiceHash() =>
    r'cfac2b7702ee191b77612945db1abbb56326cbe8';

/// Query pencarian pelanggan (nama/telepon) untuk daftar.

@ProviderFor(CustomerSearch)
const customerSearchProvider = CustomerSearchProvider._();

/// Query pencarian pelanggan (nama/telepon) untuk daftar.
final class CustomerSearchProvider
    extends $NotifierProvider<CustomerSearch, String> {
  /// Query pencarian pelanggan (nama/telepon) untuk daftar.
  const CustomerSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerSearchHash();

  @$internal
  @override
  CustomerSearch create() => CustomerSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$customerSearchHash() => r'4d8d8a316c5d1e2c032d26c36e1a4c1dea4acc66';

/// Query pencarian pelanggan (nama/telepon) untuk daftar.

abstract class _$CustomerSearch extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
