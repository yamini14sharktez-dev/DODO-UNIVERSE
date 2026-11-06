import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given Welcome endpoint', (sessionBuilder, endpoints) {
    test(
      'when calling `getWelcomeMessage` then exact welcome string is returned',
      () async {
        final message = await endpoints.welcome.getWelcomeMessage(sessionBuilder);
        expect(message, 'Welcome to DODO Universe. Backend connection successful.');
      },
    );
  });
}

