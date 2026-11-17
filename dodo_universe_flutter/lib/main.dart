import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/dev_auth_service.dart';
import 'core/auth/go_auth_service.dart';
import 'core/config/app_config.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.current();

  IAuthService? authService;
  const useDevAuth = bool.fromEnvironment('USE_DEV_AUTH', defaultValue: false);

  if (useDevAuth) {
    authService = DevAuthService();
  } else if (config.useGoBackend) {
    // Pure Go backend connection (http://localhost:8080)
    authService = GoAuthService.create(baseUrl: config.apiBaseUrl);
  } else {
    await SupabaseManager.initialize();
    if (!kReleaseMode && !SupabaseManager.isInitialized) {
      authService = DevAuthService();
    }
  }

  runApp(DodoUniverseApp(
    authService: authService,
    authenticatedScreen: DashboardScreen(authService: authService),
  ));
}

class DodoUniverseApp extends StatelessWidget {
  final IAuthService? authService;
  final Widget? home;
  final Widget? authenticatedScreen;

  const DodoUniverseApp({
    super.key,
    this.authService,
    this.home,
    this.authenticatedScreen,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DODO Universe',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: home ??
          AuthGate(
            authService: authService,
            authenticatedScreen: authenticatedScreen,
          ),
    );
  }
}
