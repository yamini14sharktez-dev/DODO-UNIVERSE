import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _client = AdminApiClient();
  bool _maintenanceMode = false;
  final int _maxLoginAttempts = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final s = await _client.getSettings();
      if (mounted) {
        setState(() {
          _maintenanceMode = s['maintenance_mode'] == true || s['maintenance_mode'] == 'true';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _client.updateSetting(key, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setting "$key" updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.pine700));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform & Security Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Operational parameters, maintenance schedules, and global security policies',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Operational Controls Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operational Safeguards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Emergency Maintenance Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('When enabled, non-admin API traffic will return 503 Service Unavailable.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                  value: _maintenanceMode,
                  activeTrackColor: AdminTheme.error,
                  onChanged: (val) {
                    setState(() => _maintenanceMode = val);
                    _updateSetting('maintenance_mode', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Parameters Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Hardening Defaults', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Max Login Attempts Before Lockout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Temporarily locks administrative accounts after consecutive failures', style: TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AdminTheme.pine50, borderRadius: BorderRadius.circular(6)),
                    child: Text('$_maxLoginAttempts attempts', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.pine800)),
                  ),
                ),
                const Divider(color: AdminTheme.borderLight),
                ListTile(
                  title: const Text('Access Token Expiry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Stateless cryptographic JWT validity window', style: TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AdminTheme.pine50, borderRadius: BorderRadius.circular(6)),
                    child: const Text('15 minutes', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.pine800)),
                  ),
                ),
                const Divider(color: AdminTheme.borderLight),
                ListTile(
                  title: const Text('Refresh Token Rotation Window', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Single-use sliding token window stored in database', style: TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AdminTheme.pine50, borderRadius: BorderRadius.circular(6)),
                    child: const Text('7 days', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.pine800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
