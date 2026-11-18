import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _client = AdminApiClient();
  final _searchController = TextEditingController();
  List<Person> _people = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getPeople(search: _searchController.text.trim());
      if (mounted) {
        setState(() {
          _people = list;
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

  Future<void> _showPersonDetails(Person person) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AdminTheme.pine700)),
    );

    try {
      final details = await _client.getPersonDetails(person.id);
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        _renderDetailsDialog(person, details);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile details: $e')),
        );
      }
    }
  }

  void _renderDetailsDialog(Person person, Map<String, dynamic> details) {
    final customerOrders = (details['customer_orders'] as List<dynamic>?) ?? [];
    final vendorApplications = (details['vendor_applications'] as List<dynamic>?) ?? [];
    final vendorListings = (details['vendor_listings'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: AdminTheme.pine700),
            const SizedBox(width: 8),
            Text(person.fullName.isEmpty ? 'User Profile' : person.fullName),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('User ID', person.id),
                _detailRow('Phone Number', person.phone),
                _detailRow('Email Address', person.email ?? 'Not provided'),
                _detailRow('System Role', person.role),
                _detailRow('Registration Completed', person.isRegistrationComplete ? 'Yes' : 'No'),
                _detailRow('Member Since', person.createdAt),
                const Divider(height: 24),
                const Text(
                  'Unified Identity Model Summary:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.pine800),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Customer Profile: Placed ${customerOrders.length} order(s).\n'
                  '• Vendor Profile: Submitted ${vendorApplications.length} application(s) and published ${vendorListings.length} listing(s).',
                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
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
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AdminTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSuspend(Person person, bool currentSuspended) async {
    final action = currentSuspended ? 'reactivate' : 'suspend';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $action'),
        content: Text('Are you sure you want to $action account for ${person.fullName.isEmpty ? person.phone : person.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: currentSuspended ? AdminTheme.pine700 : AdminTheme.error),
            child: Text(action.toUpperCase(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _client.setPersonStatus(person.id, !currentSuspended);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User account ${person.id} successfully updated.')),
          );
        }
        _loadPeople();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update user status: $e')),
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
                    'People Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Single Person Account Architecture: Unified customers and vendors',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadPeople,
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

          // Search Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadPeople(),
                    decoration: InputDecoration(
                      hintText: 'Search people by name, phone, or email...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.border),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _loadPeople,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.pine700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Search'),
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
                    : _people.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No registered people found',
                              message: 'Registered accounts will appear here automatically.',
                              icon: Icons.person_off_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _people.map((person) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(person.fullName.isEmpty ? '—' : person.fullName)),
                                    DataCell(Text(person.phone)),
                                    DataCell(Text(person.email ?? '—')),
                                    DataCell(AdminBadge(label: person.role, status: 'info')),
                                    DataCell(AdminBadge(
                                      label: person.isRegistrationComplete ? 'Active' : 'Incomplete',
                                      status: person.isRegistrationComplete ? 'active' : 'pending',
                                    )),
                                    DataCell(Text(person.createdAt.length >= 10 ? person.createdAt.substring(0, 10) : person.createdAt)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 18),
                                            tooltip: 'View Profile & Activity',
                                            color: AdminTheme.pine700,
                                            onPressed: () => _showPersonDetails(person),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.block_outlined, size: 18),
                                            tooltip: 'Suspend Account',
                                            color: AdminTheme.error,
                                            onPressed: () => _toggleSuspend(person, false),
                                          ),
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
}
