import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _client = AdminApiClient();
  String _statusFilter = '';
  List<ProductListingItem> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getListings(status: _statusFilter);
      if (mounted) {
        setState(() {
          _listings = list;
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

  Future<void> _updateApproval(ProductListingItem item, String approval) async {
    try {
      await _client.updateListingApproval(item.id, approval);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing "${item.title}" updated to $approval.')),
        );
      }
      _loadListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update listing: $e')),
        );
      }
    }
  }

  Future<void> _toggleActive(ProductListingItem item) async {
    try {
      await _client.updateListingStatus(item.id, !item.isActive);
      _loadListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle status: $e')),
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
                    'Products & Listings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Moderate vendor catalog listings, pricing, and active status',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadListings,
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
              _filterChip('All Listings', ''),
              _filterChip('Pending Moderation', 'pending'),
              _filterChip('Approved', 'approved'),
              _filterChip('Rejected', 'rejected'),
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
                    : _listings.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No listings found',
                              message: 'Vendor catalog listings will appear here for administrative moderation.',
                              icon: Icons.inventory_2_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Item Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Price & Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Transport Fee', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Approval', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _listings.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (item.description != null && item.description!.isNotEmpty)
                                          Text(
                                            item.description!.length > 40
                                                ? '${item.description!.substring(0, 40)}...'
                                                : item.description!,
                                            style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                                          ),
                                      ],
                                    )),
                                    DataCell(Text(item.vendorName ?? item.vendorId)),
                                    DataCell(Text(item.categoryName ?? item.categoryId)),
                                    DataCell(Text('₹${item.unitPrice.toStringAsFixed(2)} / ${item.pricingUnit}')),
                                    DataCell(Text(item.hasTransportation ? '₹${item.transportationFee.toStringAsFixed(2)}' : 'None')),
                                    DataCell(
                                      Switch(
                                        value: item.isActive,
                                        activeThumbColor: AdminTheme.pine700,
                                        onChanged: (_) => _toggleActive(item),
                                      ),
                                    ),
                                    DataCell(AdminBadge(label: item.approvalStatus.toUpperCase(), status: item.approvalStatus)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (item.approvalStatus != 'approved')
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, size: 18),
                                              tooltip: 'Approve Listing',
                                              color: AdminTheme.success,
                                              onPressed: () => _updateApproval(item, 'approved'),
                                            ),
                                          if (item.approvalStatus != 'rejected')
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 18),
                                              tooltip: 'Reject Listing',
                                              color: AdminTheme.error,
                                              onPressed: () => _updateApproval(item, 'rejected'),
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

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadListings();
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
