import 'package:flutter/material.dart';
import 'core/supabase/supabase_client.dart';
import 'screens/phase0_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseManager.initialize();
  runApp(const DodoUniverseApp());
}

ThemeData _buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

class DodoUniverseApp extends StatelessWidget {
  const DodoUniverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DODO Universe',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Phase0Screen(),
    );
  }
}
