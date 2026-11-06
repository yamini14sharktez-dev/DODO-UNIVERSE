import 'dart:async';

import 'package:dodo_universe_client/dodo_universe_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'core/config/app_config.dart';

late final Client client;

Future<void> initializeClient() async {
  final config = AppConfig.current();
  client = Client(config.backendApiUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();
  unawaited(client.auth.initialize());
}
