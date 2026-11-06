import 'package:flutter_test/flutter_test.dart';
import 'package:dodo_universe/core/config/app_config.dart';

void main() {
  test('AppConfig default is development', () {
    final config = AppConfig.current();
    expect(config.environment, equals(AppEnvironment.development));
    expect(config.environmentName, equals('Development'));
    expect(config.backendApiUrl, isNotEmpty);
  });
}
