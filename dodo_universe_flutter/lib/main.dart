import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/dev_auth_service.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseManager.initialize();

  // In development mode, if Supabase is uninitialized or USE_DEV_AUTH is enabled,
  // use DevAuthService so developers can test the full OTP auth flow without real SMS/email.
  IAuthService? authService;
  const useDevAuth = bool.fromEnvironment('USE_DEV_AUTH', defaultValue: false);
  if (!kReleaseMode && (useDevAuth || !SupabaseManager.isInitialized)) {
    authService = DevAuthService();
  }

  runApp(DodoUniverseApp(authService: authService));
}

class DodoUniverseApp extends StatelessWidget {
  final IAuthService? authService;

  const DodoUniverseApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DODO Universe',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: AuthGate(authService: authService),
    );
  }
}
