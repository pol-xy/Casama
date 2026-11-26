import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/colors.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'data/repository_provider.dart';
import 'data/supabase_config.dart';
import 'data/supabase_repository.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Computes the startup route for a restored repository session.
String resolveStartupRoute({
  required bool isAuthenticated,
  required bool hasActiveHousehold,
}) {
  if (!isAuthenticated) return '/';
  return hasActiveHousehold ? '/dashboard' : '/household-setup';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await SupabaseConfig.initialize();

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}

  final supabaseRepo = SupabaseRepository(SupabaseConfig.client);
  await supabaseRepo.restoreSession().timeout(
    const Duration(seconds: 6),
    onTimeout: () {},
  );

  final initialRoute = resolveStartupRoute(
    isAuthenticated: supabaseRepo.isAuthenticated,
    hasActiveHousehold: supabaseRepo.hasActiveHousehold,
  );
  final router = createAppRouter(initialLocation: initialRoute);

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null)
          themeModeProvider.overrideWith((ref) => ThemeNotifier(prefs)),
        repositoryProvider.overrideWith((ref) => supabaseRepo),
      ],
      child: CasamaApp(router: router),
    ),
  );
}

class CasamaApp extends ConsumerWidget {
  final GoRouter? router;

  const CasamaApp({super.key, this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(repositoryProvider, (_, repo) {
      final err = repo.consumePendingError();
      if (err != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final messenger = rootScaffoldMessengerKey.currentState;
          if (messenger == null) return;
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(err.message),
              backgroundColor: CasamaColors.errorRed,
              behavior: SnackBarBehavior.floating,
              action: err.onRetry != null
                  ? SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () {
                        err.onRetry?.call();
                      },
                    )
                  : null,
            ),
          );
        });
      }
    });

    return MaterialApp.router(
      title: 'Casama',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: CasamaTheme.lightTheme,
      darkTheme: CasamaTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router ?? appRouter,
    );
  }
}
