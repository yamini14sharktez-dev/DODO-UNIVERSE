import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  final _client = AdminApiClient();
  late TabController _tabController;
  List<PaymentRecordItem> _payments = [];
  List<CommissionRuleItem> _rules = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payments = await _client.getPayments();
      final rules = await _client.getCommissionRules();
      if (mounted) {
        setState(() {
          _payments = payments;
          _rules = rules;
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

  Future<void> _showRuleDialog({CommissionRuleItem? existing}) async {
    final percentCtrl = TextEditingController(text: existing != null ? existing.commissionPercent.toString() : '10.0');
    final feeCtrl = TextEditingController(text: existing != null ? existing.fixedFee.toString() : '0.0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Set Platform Commission Rule' : 'Edit Commission Rule'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: percentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Commission Percentage (%) *', suffixText: '%'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fixed Processing Fee (₹) *', prefixText: '₹'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.pine700),
            child: const Text('Save Rule', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final p = double.tryParse(percentCtrl.text.trim()) ?? 10.0;
      final f = double.tryParse(feeCtrl.text.trim()) ?? 0.0;

      try {
        await _client.setCommissionRule({
          if (existing?.categoryId != null) 'category_id': existing!.categoryId,
          'commission_percent': p,
          'fixed_fee': f,
          'is_active': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commission rule updated successfully.')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save rule: $e')),
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
                    'Payments & Commission',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Financial transaction ledger and platform commission rate configurations',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadData,
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

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminTheme.pine700,
            indicatorColor: AdminTheme.pine700,
            tabs: const [
              Tab(text: 'Transaction Ledger'),
              Tab(text: 'Commission Rules'),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildCommissionRulesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminTheme.pine700))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error)))
              : _payments.isEmpty
                  ? const EmptyStateView(
                      title: 'No payment transactions recorded',
                      message: 'Real payment transfers will appear here upon customer checkout.',
                      icon: Icons.payments_outlined,
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                        columns: const [
                          DataColumn(label: Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Payer', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _payments.map((p) {
                          return DataRow(
                            cells: [
                              DataCell(Text(p.id.length >= 8 ? '#${p.id.substring(0, 8)}' : p.id)),
                              DataCell(Text(p.payerName ?? '—')),
                              DataCell(Text('₹${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(AdminBadge(label: p.paymentType, status: 'info')),
                              DataCell(AdminBadge(label: p.status.toUpperCase(), status: p.status)),
                              DataCell(Text(p.referenceNumber ?? '—')),
                              DataCell(Text(p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
    );
  }

  Widget _buildCommissionRulesTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              const Text('Configured Commission Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                onPressed: () => _showRuleDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Rule'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.pine700, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _rules.isEmpty
                ? const EmptyStateView(
                    title: 'No custom commission rules',
                    message: 'Click "Add Rule" to configure default platform cuts and fees.',
                    icon: Icons.percent_outlined,
                  )
                : ListView.separated(
                    itemCount: _rules.length,
                    separatorBuilder: (_, __) => const Divider(color: AdminTheme.borderLight),
                    itemBuilder: (context, index) {
                      final r = _rules[index];
                      return ListTile(
                        title: Text(r.categoryName ?? 'Platform Global Default', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Commission: ${r.commissionPercent}% + ₹${r.fixedFee.toStringAsFixed(2)} fixed fee'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdminBadge(label: r.isActive ? 'Active' : 'Inactive', status: r.isActive ? 'active' : 'inactive'),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showRuleDialog(existing: r),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
