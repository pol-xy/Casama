import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'casama_repository.dart';
import 'mock_repository.dart';
import 'supabase_config.dart';
import 'supabase_repository.dart';

/// Provides the active [CasamaRepository].
/// Dynamically resolves to [SupabaseRepository] when Supabase credentials are configured,
/// or falls back to in-memory [MockRepository] for zero-setup offline development and automated testing.
final repositoryProvider = ChangeNotifierProvider<CasamaRepository>((ref) {
  final client = SupabaseConfig.client;
  if (client != null) {
    return SupabaseRepository(client);
  }
  return MockRepository();
});
