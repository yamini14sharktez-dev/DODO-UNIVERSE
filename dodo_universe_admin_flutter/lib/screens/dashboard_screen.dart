import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = AdminApiClient();
  bool _isLoading = true;
  String? _error;
  DashboardMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final metrics = await _client.getDashboardMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.pine700),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AdminTheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.pine700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final m = _metrics!;

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
                    'Platform Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time operational statistics and system health (Strictly zero mock data)',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadMetrics,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.pine700,
                  side: const BorderSide(color: AdminTheme.pine700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Primary Metric Cards Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard('Total Registered People', '${m.totalPeople}', Icons.people_outline, AdminTheme.pine700),
              _buildMetricCard('Active Vendor Profiles', '${m.activeVendors}', Icons.storefront_outlined, AdminTheme.pine600),
              _buildMetricCard('Pending Applications', '${m.pendingVendorApplications}', Icons.pending_actions, AdminTheme.warning),
              _buildMetricCard('Total Services', '${m.totalServices}', Icons.layers_outlined, AdminTheme.pine700),
              _buildMetricCard('Active Listings', '${m.totalListings}', Icons.inventory_2_outlined, AdminTheme.info),
              _buildMetricCard('Total Orders', '${m.totalOrders}', Icons.shopping_bag_outlined, AdminTheme.pine700),
              _buildMetricCard('Pending Orders', '${m.pendingOrders}', Icons.hourglass_top, AdminTheme.warning),
              _buildMetricCard('Completed Orders', '${m.completedOrders}', Icons.check_circle_outline, AdminTheme.success),
              _buildMetricCard('Pending Quotes', '${m.pendingQuoteRequests}', Icons.request_quote_outlined, AdminTheme.info),
              _buildMetricCard('Total Payment Volume', '₹${m.totalPaymentVolume.toStringAsFixed(2)}', Icons.payments_outlined, AdminTheme.pine700),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Activity Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Platform Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${m.recentActivity.length} events logged',
                        style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AdminTheme.border),
                if (m.recentActivity.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyStateView(
                      title: 'No recent platform activity',
                      message: 'Activity logs will appear in real time as administrative operations take place.',
                      icon: Icons.history_toggle_off,
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: m.recentActivity.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AdminTheme.borderLight),
                    itemBuilder: (context, index) {
                      final item = m.recentActivity[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AdminTheme.pine50,
                          child: Icon(Icons.bolt, color: AdminTheme.pine700, size: 18),
                        ),
                        title: Text(
                          '${item.adminName} (${item.adminRole}): ${item.action.toUpperCase()} on ${item.entityType}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Entity: ${item.entityId} • ${item.createdAt}',
                          style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                        ),
                        trailing: AdminBadge(
                          label: item.action,
                          status: 'info',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textSecondary,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AdminTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
