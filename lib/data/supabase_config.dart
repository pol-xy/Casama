import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static String _url = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ejewgskgnzatzczsxdvp.supabase.co',
  );
  static String _anonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_ywTPzNalFSqGeiPmrugkiQ_mHJyYYXC',
  );

  static String get defaultUrl => _url;
  static String get defaultAnonKey => _anonKey;

  static bool get isConfigured =>
      _url.trim().isNotEmpty && _anonKey.trim().isNotEmpty;

  static Future<void> initialize() async {
    // 1. Attempt to parse .env file if compile-time flags were not supplied
    if (!kIsWeb && (_url.isEmpty || _anonKey.isEmpty)) {
      try {
        final envFile = File('.env');
        if (await envFile.exists()) {
          final lines = await envFile.readAsLines();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final val = parts.sublist(1).join('=').trim();
              if (key == 'SUPABASE_URL' && _url.isEmpty) {
                _url = val;
              } else if (key == 'SUPABASE_ANON_KEY' && _anonKey.isEmpty) {
                _anonKey = val;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Initialize Supabase if credentials are present
    if (isConfigured) {
      try {
        await Supabase.initialize(
          url: _url,
          publishableKey: _anonKey,
        );
        debugPrint('Supabase initialized successfully with $_url');
      } catch (e) {
        debugPrint('Supabase init failed, falling back to mock mode: $e');
      }
    } else {
      debugPrint(
        'No Supabase credentials provided. Running in high-fidelity Mock Mode.',
      );
    }
  }

  static SupabaseClient? get client {
    if (isConfigured) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
