import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _client = AdminApiClient();
  List<AdminUser> _admins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getAdmins();
      if (mounted) {
        setState(() {
          _admins = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateAdminDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'operations_admin';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: AdminTheme.pine700),
              SizedBox(width: 8),
              Text('Provision New Administrator'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address *')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number (10 digits) *')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Initial Password *', hintText: 'Minimum 8 characters'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role-Based Access Control *'),
                    items: const [
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (Full Access)')),
                      DropdownMenuItem(value: 'operations_admin', child: Text('Operations Admin (Catalog & People)')),
                      DropdownMenuItem(value: 'finance_admin', child: Text('Finance Admin (Payments & Ledger)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => role = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.pine700),
              child: const Text('Provision Admin', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        nameCtrl.text.trim().isNotEmpty &&
        emailCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty &&
        passCtrl.text.trim().length >= 8) {
      try {
        await _client.createAdmin({
          'full_name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'password': passCtrl.text.trim(),
          'role': role,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Administrator "${nameCtrl.text.trim()}" provisioned.')),
          );
        }
        _loadAdmins();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to provision admin: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleAdminActive(AdminUser admin) async {
    try {
      await _client.updateAdmin(admin.id, {'is_active': !admin.isActive});
      _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle admin status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'Admin Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Super Admin control console: Provision and manage administrative personnel and scopes',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadAdmins,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.pine700,
                      side: const BorderSide(color: AdminTheme.pine700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showCreateAdminDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('New Administrator'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.pine700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Table
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: AdminTheme.pine700)),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error))),
                      )
                    : _admins.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No administrators found',
                              message: 'Use "New Administrator" to add staff members.',
                              icon: Icons.admin_panel_settings_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Role Scope', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Last Login', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _admins.map((admin) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(admin.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(admin.email)),
                                    DataCell(Text(admin.phone)),
                                    DataCell(AdminBadge(label: admin.role, status: 'active')),
                                    DataCell(
                                      Switch(
                                        value: admin.isActive,
                                        activeThumbColor: AdminTheme.pine700,
                                        onChanged: (_) => _toggleAdminActive(admin),
                                      ),
                                    ),
                                    DataCell(Text(admin.lastLoginAt ?? 'Never')),
                                    DataCell(Text(admin.createdAt.length >= 10 ? admin.createdAt.substring(0, 10) : admin.createdAt)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
