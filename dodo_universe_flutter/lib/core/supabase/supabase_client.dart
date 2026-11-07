import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseManager {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase has not been initialized. Call SupabaseManager.initialize() first.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<bool> initialize() async {
    final config = AppConfig.current();
    if (config.supabaseUrl.isEmpty || config.supabaseAnonKey.isEmpty) {
      debugPrint(
        'SupabaseManager: Supabase URL or Anon Key is empty. '
        'Set via --dart-define=SUPABASE_ANON_KEY=... or in app_config.dart.',
      );
      _initialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('SupabaseManager: Failed to initialize Supabase: $e');
      _initialized = false;
      return false;
    }
  }
}

