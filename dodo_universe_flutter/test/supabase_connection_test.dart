import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dodo_universe/core/config/app_config.dart';
import 'package:dodo_universe/core/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppConfig loads Supabase URL and Publishable Key', () {
    final config = AppConfig.current();
    expect(config.supabaseUrl, equals('https://swivkawtnqymvymjxlpl.supabase.co'));
    expect(config.supabasePublishableKey, isNotEmpty);
    expect(config.supabasePublishableKey, startsWith('sb_publishable_'));
  });

  test('Supabase initializes and auth instance is ready', () async {
    final success = await SupabaseManager.initialize();
    expect(success, isTrue);
    expect(SupabaseManager.isInitialized, isTrue);

    // Verify Auth readiness
    final client = SupabaseManager.client;
    expect(client.auth, isNotNull);
    expect(client.auth.currentSession, isNull);
    expect(client.auth.currentUser, isNull);
  });
}
