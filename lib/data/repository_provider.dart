import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'casama_repository.dart';
import 'supabase_config.dart';
import 'supabase_repository.dart';

export 'casama_repository.dart' show CasamaRepositoryNameX;

/// Provides the active runtime [CasamaRepository] backed exclusively by [SupabaseRepository].
/// Automated tests can explicitly override this provider with `MockRepository`.
final repositoryProvider = ChangeNotifierProvider<CasamaRepository>((ref) {
  return SupabaseRepository(SupabaseConfig.client);
});
