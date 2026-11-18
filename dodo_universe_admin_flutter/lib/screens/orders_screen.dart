import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _client = AdminApiClient();
  final _searchController = TextEditingController();
  String _statusFilter = '';
  List<AdminOrderItem> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getOrders(
        status: _statusFilter,
        search: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _orders = list;
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

  void _viewOrder(AdminOrderItem order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AdminTheme.pine700),
            const SizedBox(width: 8),
            Text('Order #${order.id}'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Status', order.status.toUpperCase()),
                _row('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'),
                _row('Platform Commission', '₹${order.commissionAmount.toStringAsFixed(2)}'),
                const Divider(height: 16),
                _row('Customer Name', order.customerName ?? '—'),
                _row('Customer Phone', order.customerPhone ?? '—'),
                const Divider(height: 16),
                _row('Vendor Name', order.vendorName ?? '—'),
                _row('Vendor Phone', order.vendorPhone ?? '—'),
                const Divider(height: 16),
                if (order.disputeReason != null) ...[
                  _row('Dispute Reason', order.disputeReason!),
                  if (order.disputeResolution != null)
                    _row('Dispute Resolution', order.disputeResolution!),
                  const Divider(height: 16),
                ],
                const Text('Order Specification & Line Items:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.pine800)),
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
                    order.orderDetails.isEmpty ? 'No extra line items.' : order.orderDetails.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
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
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AdminTheme.textPrimary))),
        ],
      ),
    );
  }

  Future<void> _resolveDispute(AdminOrderItem order) async {
    final resolutionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Order Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter formal administrative resolution for Order #${order.id}:'),
            const SizedBox(height: 12),
            TextField(
              controller: resolutionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Refund issued to customer / Vendor penalty applied...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.pine700),
            child: const Text('Confirm Resolution', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && resolutionController.text.trim().isNotEmpty) {
      try {
        await _client.resolveOrderDispute(order.id, resolutionController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dispute on Order #${order.id} resolved.')),
          );
        }
        _loadOrders();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resolve dispute: $e')),
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
                    'Bookings & Orders',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track platform bookings, commissions, order states, and dispute resolution',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadOrders,
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

          // Filters and Search
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadOrders(),
                    decoration: InputDecoration(
                      hintText: 'Search orders by ID, customer, or vendor...',
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
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.pine700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            children: [
              _filterChip('All Orders', ''),
              _filterChip('Pending', 'pending'),
              _filterChip('Confirmed', 'confirmed'),
              _filterChip('Completed', 'completed'),
              _filterChip('Cancelled', 'cancelled'),
              _filterChip('Disputed', 'disputed'),
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
                    : _orders.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No orders found',
                              message: 'Placed orders and service bookings will appear here in real time.',
                              icon: Icons.shopping_bag_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Commission (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _orders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(order.id.length >= 8 ? '#${order.id.substring(0, 8)}' : order.id,
                                        style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(order.customerName ?? order.customerId)),
                                    DataCell(Text(order.vendorName ?? order.vendorId)),
                                    DataCell(Text('₹${order.totalAmount.toStringAsFixed(2)}')),
                                    DataCell(Text('₹${order.commissionAmount.toStringAsFixed(2)}')),
                                    DataCell(AdminBadge(label: order.status.toUpperCase(), status: order.status)),
                                    DataCell(Text(order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 18),
                                            tooltip: 'View Order Details',
                                            color: AdminTheme.pine700,
                                            onPressed: () => _viewOrder(order),
                                          ),
                                          if (order.status == 'disputed')
                                            IconButton(
                                              icon: const Icon(Icons.gavel_outlined, size: 18),
                                              tooltip: 'Resolve Dispute',
                                              color: AdminTheme.warning,
                                              onPressed: () => _resolveDispute(order),
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
        _loadOrders();
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
