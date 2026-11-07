import 'package:flutter_test/flutter_test.dart';
import 'package:dodo_universe/core/config/app_config.dart';

void main() {
  test('AppConfig defaults to development and has Supabase URL', () {
    final config = AppConfig.current();
    expect(config.environment, equals(AppEnvironment.development));
    expect(config.environmentName, equals('Development'));
    expect(config.supabaseUrl, equals('https://swivkawtnqymvymjxlpl.supabase.co'));
    expect(config.supabasePublishableKey, isNotNull);
  });
}
