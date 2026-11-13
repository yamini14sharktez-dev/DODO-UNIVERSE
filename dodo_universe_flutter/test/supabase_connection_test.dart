import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dodo_universe/core/config/app_config.dart';
import 'package:dodo_universe/core/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppConfig loads Supabase URL and Publishable Key safely', () {
    final config = AppConfig.current();
    expect(
        config.supabaseUrl, equals('https://swivkawtnqymvymjxlpl.supabase.co'));
    // In CI without --dart-define, publishable key defaults to empty string safely
    expect(config.supabasePublishableKey, isNotNull);
  });

  test('SupabaseManager safely handles missing credentials without crashing',
      () async {
    const emptyConfig = AppConfig(
      environment: AppEnvironment.development,
      environmentName: 'TestEmpty',
      supabaseUrl: '',
      supabasePublishableKey: '',
    );
    final success = await SupabaseManager.initialize(config: emptyConfig);
    expect(success, isFalse);
    expect(SupabaseManager.isInitialized, isFalse);
  });

  test(
      'Supabase initializes and auth instance is ready with test configuration',
      () async {
    const testConfig = AppConfig(
      environment: AppEnvironment.development,
      environmentName: 'Test',
      supabaseUrl: 'https://swivkawtnqymvymjxlpl.supabase.co',
      supabasePublishableKey: 'sb_publishable_test_mock_key',
    );
    final success = await SupabaseManager.initialize(config: testConfig);
    expect(success, isTrue);
    expect(SupabaseManager.isInitialized, isTrue);

    // Verify Auth readiness
    final client = SupabaseManager.client;
    expect(client.auth, isNotNull);
    expect(client.auth.currentSession, isNull);
    expect(client.auth.currentUser, isNull);
  });
}
