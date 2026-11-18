import 'package:flutter/material.dart';
import 'core/auth_state.dart';
import 'core/theme.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DodoUniverseAdminApp());
}

class DodoUniverseAdminApp extends StatefulWidget {
  const DodoUniverseAdminApp({super.key});

  @override
  State<DodoUniverseAdminApp> createState() => _DodoUniverseAdminAppState();
}

class _DodoUniverseAdminAppState extends State<DodoUniverseAdminApp> {
  final _authState = AdminAuthState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authState,
      builder: (context, _) {
        return MaterialApp(
          title: 'DODO Universe – Admin Panel',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.lightTheme,
          home: _authState.isAuthenticated
              ? AdminShellScreen(authState: _authState)
              : LoginScreen(authState: _authState),
        );
      },
    );
  }
}
