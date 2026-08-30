import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_provider.dart';
import '../data/business_repository.dart';

part 'onboarding_providers.g.dart';

@riverpod
BusinessRepository businessRepository(Ref ref) =>
    BusinessRepository(ref.watch(appDatabaseProvider));
