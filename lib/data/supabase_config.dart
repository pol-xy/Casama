import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String avatarsBucket = 'avatars';
  static const String casnapsBucket = 'casnaps';
  static const String chatAttachmentsBucket = 'chat-attachments';

  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _envAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String _envDemoEmail = String.fromEnvironment(
    'SUPABASE_DEMO_EMAIL',
    defaultValue: '',
  );
  static const String _envDemoPassword = String.fromEnvironment(
    'SUPABASE_DEMO_PASSWORD',
    defaultValue: '',
  );

  static bool _initialized = false;

  static String _readEnv(String key, String compileTimeDefault) {
    if (dotenv.isInitialized) {
      final value = dotenv.env[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return compileTimeDefault.trim();
  }

  static String get defaultUrl => _readEnv('SUPABASE_URL', _envUrl);
  static String get defaultAnonKey =>
      _readEnv('SUPABASE_ANON_KEY', _envAnonKey);
  static String get demoEmail => _readEnv('SUPABASE_DEMO_EMAIL', _envDemoEmail);
  static String get demoPassword =>
      _readEnv('SUPABASE_DEMO_PASSWORD', _envDemoPassword);

  static bool get isConfigured =>
      defaultUrl.isNotEmpty && defaultAnonKey.isNotEmpty;

  static bool get isInitialized => _initialized;

  static bool get hasDemoCredentials =>
      demoEmail.isNotEmpty && demoPassword.isNotEmpty;

  static Future<void> initialize() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {}
    }

    final url = defaultUrl;
    final anonKey = defaultAnonKey;

    if (url.isNotEmpty && anonKey.isNotEmpty && !_initialized) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
        );
        _initialized = true;
        debugPrint('Supabase initialized successfully for $url');
      } catch (e) {
        debugPrint('Supabase initialization failed: $e');
      }
    } else if (url.isEmpty || anonKey.isEmpty) {
      debugPrint(
        'SupabaseConfig: SUPABASE_URL and SUPABASE_ANON_KEY not set. Live requests require .env or --dart-define configuration.',
      );
    }
  }

  static SupabaseClient? get client {
    if (_initialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
