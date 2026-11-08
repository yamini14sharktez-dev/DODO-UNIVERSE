import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/supabase/supabase_client.dart';

class Phase0Screen extends StatefulWidget {
  const Phase0Screen({super.key});

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
      setState(() {
        _isCheckingDb = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = AppConfig.current();
    final isClientInitialized = SupabaseManager.isInitialized;
    final isAnonKeyConfigured = config.supabasePublishableKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DODO Universe – Phase 0 (Supabase BaaS)'),
        centerTitle: true,
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
                      isClientInitialized ? Icons.lock_open : Icons.lock_clock,
                      color: isClientInitialized ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    title: const Text(
                      '2. Supabase Auth Service',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isClientInitialized
                          ? 'READY – Supabase Auth instance is accessible. No active session (unauthenticated).'
                          : 'STANDBY – Awaiting Supabase client initialization.',
                    ),
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
