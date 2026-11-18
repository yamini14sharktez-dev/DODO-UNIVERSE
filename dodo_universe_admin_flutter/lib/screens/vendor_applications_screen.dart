import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class VendorApplicationsScreen extends StatefulWidget {
  const VendorApplicationsScreen({super.key});

  @override
  State<VendorApplicationsScreen> createState() => _VendorApplicationsScreenState();
}

class _VendorApplicationsScreenState extends State<VendorApplicationsScreen> {
  final _client = AdminApiClient();
  String _statusFilter = '';
  List<VendorApplicationItem> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getVendorApplications(status: _statusFilter);
      if (mounted) {
        setState(() {
          _applications = list;
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

  void _inspectApplication(VendorApplicationItem app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AdminTheme.pine700),
            const SizedBox(width: 8),
            Text(app.businessName.isEmpty ? 'Vendor Application' : app.businessName),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Application ID', app.id),
                _detailRow('Applicant Name', app.userFullName),
                _detailRow('Applicant Phone', app.userPhone),
                _detailRow('Applicant Email', app.userEmail ?? 'Not provided'),
                _detailRow('Business Type', app.businessType ?? 'Not specified'),
                _detailRow('Current Status', app.status.toUpperCase()),
                _detailRow('Submitted At', app.createdAt),
                if (app.rejectionReason != null)
                  _detailRow('Rejection Reason', app.rejectionReason!),
                if (app.infoRequestNotes != null)
                  _detailRow('Admin Request Notes', app.infoRequestNotes!),
                const Divider(height: 24),
                const Text(
                  'Submitted Form Payload (JSONB):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.pine800),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Text(
                    app.submittedData.isEmpty ? 'No extra form parameters provided.' : app.submittedData.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uploaded Documents:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.pine800),
                ),
                const SizedBox(height: 8),
                if (app.documents.isEmpty)
                  const Text('No verification documents uploaded.', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 12))
                else
                  ...app.documents.map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.attachment, size: 16, color: AdminTheme.pine700),
                            const SizedBox(width: 6),
                            Expanded(child: Text(d.toString(), style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AdminTheme.textPrimary))),
        ],
      ),
    );
  }

  Future<void> _approve(VendorApplicationItem app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Vendor Application'),
        content: Text('Are you sure you want to approve "${app.businessName}"? This will activate their vendor profile on the platform.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _client.approveVendorApplication(app.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vendor "${app.businessName}" approved successfully!')),
          );
        }
        _loadApplications();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve application: $e')),
          );
        }
      }
    }
  }

  Future<void> _reject(VendorApplicationItem app) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Vendor Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the reason for rejecting "${app.businessName}":'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter detailed rejection reason for vendor feedback...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            child: const Text('Reject Application', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _client.rejectVendorApplication(app.id, reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vendor "${app.businessName}" application rejected.')),
          );
        }
        _loadApplications();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject application: $e')),
          );
        }
      }
    }
  }

  Future<void> _requestInfo(VendorApplicationItem app) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Information / Clarification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the information needed from "${app.businessName}":'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Specify what documents or details are required...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.warning),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && notesController.text.trim().isNotEmpty) {
      try {
        await _client.requestInfoVendorApplication(app.id, notesController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Information request sent to "${app.businessName}".')),
          );
        }
        _loadApplications();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to request information: $e')),
          );
        }
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
                    'Vendor Applications',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review, verify documentation, approve, reject, or request clarification',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadApplications,
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

          // Filter bar
          Wrap(
            spacing: 8,
            children: [
              _filterChip('All Applications', ''),
              _filterChip('Pending', 'pending'),
              _filterChip('Approved', 'approved'),
              _filterChip('Rejected', 'rejected'),
              _filterChip('Info Requested', 'info_requested'),
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
                    : _applications.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No vendor applications found',
                              message: 'Applications submitted by prospective vendors will appear here.',
                              icon: Icons.assignment_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Business Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Applicant', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Submitted Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _applications.map((app) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(app.businessName.isEmpty ? '—' : app.businessName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(app.userFullName)),
                                    DataCell(Text(app.userPhone)),
                                    DataCell(AdminBadge(label: app.status.toUpperCase(), status: app.status)),
                                    DataCell(Text(app.createdAt.length >= 10 ? app.createdAt.substring(0, 10) : app.createdAt)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 18),
                                            tooltip: 'Inspect Application & Docs',
                                            color: AdminTheme.pine700,
                                            onPressed: () => _inspectApplication(app),
                                          ),
                                          if (app.status == 'pending' || app.status == 'info_requested') ...[
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, size: 18),
                                              tooltip: 'Approve Application',
                                              color: AdminTheme.success,
                                              onPressed: () => _approve(app),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 18),
                                              tooltip: 'Reject Application',
                                              color: AdminTheme.error,
                                              onPressed: () => _reject(app),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.help_outline, size: 18),
                                              tooltip: 'Request Information',
                                              color: AdminTheme.warning,
                                              onPressed: () => _requestInfo(app),
                                            ),
                                          ],
                                        ],
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
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadApplications();
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
