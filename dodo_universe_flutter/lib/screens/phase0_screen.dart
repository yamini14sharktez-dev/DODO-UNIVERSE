import 'package:flutter/material.dart';
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
        _dbStatus = 'Cannot test database: Supabase client is not initialized. Anon Key is required.';
        _dbVerified = false;
      });
      return;
    }

    setState(() {
      _isCheckingDb = true;
      _dbStatus = null;
    });

    try {
      // Execute an actual database API query to verify PostgREST/PostgreSQL connectivity
      final response = await SupabaseManager.client
          .from('_phase0_test')
          .select()
          .limit(1)
          .maybeSingle();

      setState(() {
        _dbVerified = true;
        _dbStatus = 'Database API request succeeded! Response: $response';
      });
    } catch (e) {
      final errorString = e.toString();
      // If table does not exist (PGRST204 or 42P01), the connection to Supabase PostgREST still succeeded
      if (errorString.contains('42P01') || errorString.contains('PGRST204') || errorString.contains('relation') || errorString.contains('does not exist')) {
        setState(() {
          _dbVerified = true;
          _dbStatus = 'Database API connection verified! PostgREST responded (no business tables created yet, as expected).';
        });
      } else {
        setState(() {
          _dbVerified = false;
          _dbStatus = 'Database API request failed: $errorString';
        });
      }
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
    final isAnonKeyConfigured = config.supabaseAnonKey.isNotEmpty;

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
                          'Publishable/Anon Key: ${isAnonKeyConfigured ? "Configured (${config.supabaseAnonKey.substring(0, 8)}...)" : "NOT SET (Provide via --dart-define=SUPABASE_ANON_KEY=...)"}',
                          style: TextStyle(
                            color: isAnonKeyConfigured ? Colors.green.shade700 : Colors.orange.shade800,
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
                      isClientInitialized ? Icons.check_circle : Icons.warning_amber_rounded,
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
                          : 'NOT INITIALIZED – Provide SUPABASE_ANON_KEY to initialize client.',
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

                // 3. Database API Verification
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
                                '3. Supabase Database API Verification',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_sync),
                              label: const Text('Verify DB API'),
                              onPressed: _isCheckingDb ? null : _testDatabaseApi,
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
                            'Click "Verify DB API" to execute a live PostgREST API request against the Supabase database. Note: Client initialization alone does not mean database connectivity is verified.',
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
