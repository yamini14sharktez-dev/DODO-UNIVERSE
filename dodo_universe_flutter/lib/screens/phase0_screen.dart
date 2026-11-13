import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/auth/auth_service.dart';
import '../core/config/app_config.dart';
import '../core/supabase/supabase_client.dart';
import 'auth/auth_gate.dart';

class Phase0Screen extends StatefulWidget {
  final IAuthService? authService;

  const Phase0Screen({super.key, this.authService});

  @override
  State<Phase0Screen> createState() => _Phase0ScreenState();
}

class _Phase0ScreenState extends State<Phase0Screen> {
  bool _isCheckingDb = false;
  String? _dbStatus;
  bool _dbVerified = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _testDatabaseApi() async {
    if (!SupabaseManager.isInitialized) {
      setState(() {
        _dbStatus =
            'Cannot test API: Supabase client is not initialized. Publishable key is required.';
        _dbVerified = false;
      });
      return;
    }

    setState(() {
      _isCheckingDb = true;
      _dbStatus = null;
    });

    try {
      final config = AppConfig.current();
      final url = Uri.parse('${config.supabaseUrl}/rest/v1/');
      final req = http.Request('OPTIONS', url)
        ..headers['apikey'] = config.supabasePublishableKey;

      final client = http.Client();
      final streamed = await client.send(req);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final projectRef =
            res.headers['sb-project-ref'] ?? 'swivkawtnqymvymjxlpl';
        setState(() {
          _dbVerified = true;
          _dbStatus = 'REST API Gateway: CONNECTED (HTTP 200 OK)\n'
              'Project: $projectRef\n'
              'Authentication: Publishable Key accepted\n'
              'Database Query Status: STANDBY (No application tables created yet)';
        });
      } else {
        setState(() {
          _dbVerified = false;
          _dbStatus =
              'API Gateway returned HTTP ${res.statusCode}: ${res.body}';
        });
      }
    } catch (e) {
      setState(() {
        _dbVerified = false;
        _dbStatus = 'API connection probe failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDb = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final auth = widget.authService ?? AuthService.instance;
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('Phase0Screen logout error: $e');
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => AuthGate(authService: widget.authService),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = AppConfig.current();
    final isClientInitialized = SupabaseManager.isInitialized;
    final isAnonKeyConfigured = config.supabasePublishableKey.isNotEmpty;
    final auth = widget.authService ?? AuthService.instance;
    final currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DODO Universe – Phase 0 (Supabase BaaS)'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('phase0_logout_button'),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Environment Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Environment & Supabase Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Environment: ${config.environmentName}'),
                        Text('Project URL: ${config.supabaseUrl}'),
                        Text(
                          'Publishable Key: ${isAnonKeyConfigured ? "Configured (${config.supabasePublishableKey.substring(0, 14)}...)" : "NOT SET (Provide via env.json or --dart-define)"}',
                          style: TextStyle(
                            color: isAnonKeyConfigured
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Client Initialization Status
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      isClientInitialized
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: isClientInitialized ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    title: const Text(
                      '1. Supabase Client Initialization',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isClientInitialized
                          ? 'INITIALIZED – Client instance is active with project URL.'
                          : 'NOT INITIALIZED – Provide SUPABASE_PUBLISHABLE_KEY to initialize client.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Auth Service Status
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      currentUser != null
                          ? Icons.check_circle
                          : (isClientInitialized
                              ? Icons.lock_open
                              : Icons.lock_clock),
                      color: currentUser != null
                          ? Colors.green
                          : (isClientInitialized ? Colors.green : Colors.grey),
                      size: 32,
                    ),
                    title: const Text(
                      '2. Supabase Auth Service',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      currentUser != null
                          ? 'AUTHENTICATED – User: ${currentUser.phone ?? currentUser.email ?? currentUser.id}\nStatus: Completed Registration.'
                          : (isClientInitialized
                              ? 'READY – Supabase Auth instance is accessible. No active session (unauthenticated).'
                              : 'STANDBY – Awaiting Supabase client initialization.'),
                    ),
                    trailing: currentUser != null
                        ? TextButton(
                            key: const Key('auth_card_logout_button'),
                            onPressed: _handleLogout,
                            child: const Text('Logout'),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Database & REST API Verification
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                '3. Supabase REST API & Database Verification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(140, 40),
                              ),
                              icon: const Icon(Icons.cloud_sync),
                              label: const Text('Verify API Gateway'),
                              onPressed:
                                  _isCheckingDb ? null : _testDatabaseApi,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isCheckingDb)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_dbStatus != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _dbVerified
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _dbStatus!,
                              style: TextStyle(
                                color: _dbVerified
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Click "Verify API Gateway" to probe the PostgREST gateway via HTTP OPTIONS. It tests gateway authentication and project routing without requiring any database tables.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
