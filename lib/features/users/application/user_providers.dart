import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/session_controller.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/user_repository.dart';
import '../domain/current_user.dart';
import '../domain/permission.dart';

part 'user_providers.g.dart';

@riverpod
UserRepository userRepository(Ref ref) =>
    UserRepository(ref.watch(appDatabaseProvider));

/// Daftar user (kelola karyawan) — baris Drift → StreamProvider manual.
final userListProvider = StreamProvider.autoDispose<List<User>>(
  (ref) => ref.watch(userRepositoryProvider).watchUsers(),
);

/// User aktif untuk layar login (baris Drift → StreamProvider manual).
final loginableUsersProvider = StreamProvider.autoDispose<List<User>>(
  (ref) => ref.watch(userRepositoryProvider).watchLoginableUsers(),
);

/// User yang sedang login (dari sesi) — sumber kebenaran gating.
@riverpod
CurrentUser? currentUser(Ref ref) =>
    ref.watch(sessionControllerProvider).currentUser;

/// Himpunan permission efektif user aktif (kosong bila belum login).
@riverpod
Set<Permission> permissions(Ref ref) =>
    ref.watch(currentUserProvider)?.permissions ?? const <Permission>{};

/// Apakah user aktif punya [permission]? Owner selalu true. Dipakai untuk
/// gating UI/route/aksi (family reaktif).
@riverpod
bool can(Ref ref, Permission permission) =>
    ref.watch(currentUserProvider)?.can(permission) ?? false;
