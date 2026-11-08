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

  static Future<bool> initialize({AppConfig? config}) async {
    final effectiveConfig = config ?? AppConfig.current();
    if (effectiveConfig.supabaseUrl.isEmpty ||
        effectiveConfig.supabasePublishableKey.isEmpty) {
      debugPrint(
        'SupabaseManager: Supabase URL or Publishable Key is empty. '
        'Set via --dart-define=SUPABASE_PUBLISHABLE_KEY=... or --dart-define-from-file=env.json.',
      );
      _initialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: effectiveConfig.supabaseUrl,
        publishableKey: effectiveConfig.supabasePublishableKey,
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
