// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userRepository)
const userRepositoryProvider = UserRepositoryProvider._();

final class UserRepositoryProvider
    extends $FunctionalProvider<UserRepository, UserRepository, UserRepository>
    with $Provider<UserRepository> {
  const UserRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRepository create(Ref ref) {
    return userRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRepository>(value),
    );
  }
}

String _$userRepositoryHash() => r'c624af21d772c4c8da6b0098957adf68bf64dcf6';

/// User yang sedang login (dari sesi) — sumber kebenaran gating.

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

/// User yang sedang login (dari sesi) — sumber kebenaran gating.

final class CurrentUserProvider
    extends $FunctionalProvider<CurrentUser?, CurrentUser?, CurrentUser?>
    with $Provider<CurrentUser?> {
  /// User yang sedang login (dari sesi) — sumber kebenaran gating.
  const CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<CurrentUser?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CurrentUser? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrentUser? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrentUser?>(value),
    );
  }
}

String _$currentUserHash() => r'9141e1182e68814e50d8868a60b863895ee8b9c4';

/// Himpunan permission efektif user aktif (kosong bila belum login).

@ProviderFor(permissions)
const permissionsProvider = PermissionsProvider._();

/// Himpunan permission efektif user aktif (kosong bila belum login).

final class PermissionsProvider
    extends
        $FunctionalProvider<Set<Permission>, Set<Permission>, Set<Permission>>
    with $Provider<Set<Permission>> {
  /// Himpunan permission efektif user aktif (kosong bila belum login).
  const PermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'permissionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$permissionsHash();

  @$internal
  @override
  $ProviderElement<Set<Permission>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<Permission> create(Ref ref) {
    return permissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<Permission> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<Permission>>(value),
    );
  }
}

String _$permissionsHash() => r'5d6383905b2c63122c2a8851ec265fe3252f77ff';

/// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
/// gating UI/route/aksi (family reaktif).

@ProviderFor(can)
const canProvider = CanFamily._();

/// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
/// gating UI/route/aksi (family reaktif).

final class CanProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
  /// gating UI/route/aksi (family reaktif).
  const CanProvider._({
    required CanFamily super.from,
    required Permission super.argument,
  }) : super(
         retry: null,
         name: r'canProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$canHash();

  @override
  String toString() {
    return r'canProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as Permission;
    return can(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$canHash() => r'abd4d727980e7566ddf7af23351e86f1e7f247d8';

/// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
/// gating UI/route/aksi (family reaktif).

final class CanFamily extends $Family
    with $FunctionalFamilyOverride<bool, Permission> {
  const CanFamily._()
    : super(
        retry: null,
        name: r'canProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
  /// gating UI/route/aksi (family reaktif).

  CanProvider call(Permission permission) =>
      CanProvider._(argument: permission, from: this);

  @override
  String toString() => r'canProvider';
}
