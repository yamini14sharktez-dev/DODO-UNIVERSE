import 'package:flutter/material.dart';

import '../client.dart';
import '../core/config/app_config.dart';

class Phase0Screen extends StatefulWidget {
  const Phase0Screen({super.key});

  @override
  State<Phase0Screen> createState() => _Phase0ScreenState();
}

class _Phase0ScreenState extends State<Phase0Screen> {
  String? _apiMessage;
  String? _apiError;
  bool _isApiLoading = false;

  String? _dbMessage;
  String? _dbError;
  bool _isDbLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWelcomeMessage();
  }

  Future<void> _fetchWelcomeMessage() async {
    setState(() {
      _isApiLoading = true;
      _apiError = null;
    });

    try {
      final message = await client.welcome.getWelcomeMessage();
      setState(() {
        _apiMessage = message;
      });
    } catch (e) {
      setState(() {
        _apiError = e.toString();
      });
    } finally {
      setState(() {
        _isApiLoading = false;
      });
    }
  }

  Future<void> _checkDatabaseConnectivity() async {
    setState(() {
      _isDbLoading = true;
      _dbError = null;
    });

    try {
      final status = await client.welcome.checkDatabase();
      setState(() {
        _dbMessage = status;
      });
    } catch (e) {
      setState(() {
        _dbError = e.toString();
      });
    } finally {
      setState(() {
        _isDbLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = AppConfig.current();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DODO Universe – Phase 0 Verification'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
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
                          'Environment Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Target Environment: ${config.environmentName}'),
                        Text('Backend Endpoint: ${config.backendApiUrl}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // API Communication Card
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
                            Text(
                              '1. API Communication',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _isApiLoading ? null : _fetchWelcomeMessage,
                              tooltip: 'Refresh API Message',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isApiLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_apiError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Error: $_apiError',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _apiMessage ?? 'No message received.',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Database Connectivity Card
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
                            Text(
                              '2. Supabase PostgreSQL Connectivity',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.storage),
                              label: const Text('Test Database'),
                              onPressed: _isDbLoading ? null : _checkDatabaseConnectivity,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isDbLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_dbError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Database Error: $_dbError',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          )
                        else if (_dbMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _dbMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Click "Test Database" to verify the backend-to-Supabase PostgreSQL connection separately from API calls.',
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

