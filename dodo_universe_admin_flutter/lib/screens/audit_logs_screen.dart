import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _client = AdminApiClient();
  String _entityFilter = '';
  final String _actionFilter = '';
  List<AuditLogItem> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getAuditLogs(
        entityType: _entityFilter,
        action: _actionFilter,
      );
      if (mounted) {
        setState(() {
          _logs = list;
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

  void _viewDiff(AuditLogItem log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: AdminTheme.pine700),
            const SizedBox(width: 8),
            Text('Audit Trail Record #${log.id}'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Admin', '${log.adminName} (${log.adminRole})'),
                _row('Action', log.action.toUpperCase()),
                _row('Target Entity', '${log.entityType} (ID: ${log.entityId})'),
                _row('IP Address', log.ipAddress ?? '—'),
                _row('Timestamp', log.createdAt),
                const Divider(height: 20),
                const Text('Before Mutation (Old State):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.error)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AdminTheme.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: AdminTheme.border)),
                  child: Text(log.oldValues == null ? 'None (New Record Creation)' : log.oldValues.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                ),
                const SizedBox(height: 16),
                const Text('After Mutation (New State):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.success)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AdminTheme.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: AdminTheme.border)),
                  child: Text(log.newValues == null ? 'None (Record Deleted)' : log.newValues.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AdminTheme.textPrimary))),
        ],
      ),
    );
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
                    'Audit Logs',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Immutable tamper-evident record of all administrative write actions and state modifications',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.pine700,
                  side: const BorderSide(color: AdminTheme.pine700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          Wrap(
            spacing: 8,
            children: [
              _filterChip('All Actions', ''),
              _filterChip('Category Changes', 'category'),
              _filterChip('Listing Moderations', 'listing'),
              _filterChip('Vendor Approvals', 'vendor_application'),
              _filterChip('User Updates', 'people'),
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
                    : _logs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No audit records recorded yet',
                              message: 'All administrative state mutations will be logged here permanently.',
                              icon: Icons.history_toggle_off,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Entity Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Entity ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('IP Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Diff', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _logs.map((log) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(log.createdAt.length >= 19 ? log.createdAt.substring(0, 19).replaceAll('T', ' ') : log.createdAt)),
                                    DataCell(Text('${log.adminName} (${log.adminRole})')),
                                    DataCell(AdminBadge(label: log.action.toUpperCase(), status: 'info')),
                                    DataCell(Text(log.entityType)),
                                    DataCell(Text(log.entityId.length >= 8 ? log.entityId.substring(0, 8) : log.entityId)),
                                    DataCell(Text(log.ipAddress ?? '—')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.difference_outlined, size: 18),
                                        tooltip: 'Inspect Before/After Diff',
                                        color: AdminTheme.pine700,
                                        onPressed: () => _viewDiff(log),
                                      ),
                                    ),
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

  Widget _filterChip(String label, String value) {
    final isSelected = _entityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _entityFilter = value);
        _loadLogs();
      },
      selectedColor: AdminTheme.pine100,
      labelStyle: TextStyle(
        color: isSelected ? AdminTheme.pine800 : AdminTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
