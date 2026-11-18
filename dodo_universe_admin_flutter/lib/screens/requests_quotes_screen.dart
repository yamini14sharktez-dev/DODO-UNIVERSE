import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/admin_badge.dart';
import '../widgets/empty_state_view.dart';

class RequestsQuotesScreen extends StatefulWidget {
  const RequestsQuotesScreen({super.key});

  @override
  State<RequestsQuotesScreen> createState() => _RequestsQuotesScreenState();
}

class _RequestsQuotesScreenState extends State<RequestsQuotesScreen> {
  final _client = AdminApiClient();
  String _statusFilter = '';
  List<QuotationRequestItem> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _client.getQuotationRequests(status: _statusFilter);
      if (mounted) {
        setState(() {
          _requests = list;
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

  void _inspectRequest(QuotationRequestItem req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.request_quote_outlined, color: AdminTheme.pine700),
            const SizedBox(width: 8),
            Text(req.title.isEmpty ? 'Quotation Request' : req.title),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Request ID', req.id),
                _row('Customer', req.customerName ?? req.customerId),
                _row('Category', req.categoryName ?? '—'),
                _row('Status', req.status.toUpperCase()),
                _row('Created At', req.createdAt),
                const Divider(height: 20),
                const Text('Customer Request Parameters (Dynamic Form JSON):',
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
                    req.details.isEmpty ? 'No extra parameters provided.' : req.details.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Vendor Bids Received (${req.quotations.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.pine800)),
                const SizedBox(height: 8),
                if (req.quotations.isEmpty)
                  const Text('No vendor quotations submitted yet.', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 12))
                else
                  ...req.quotations.map((q) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AdminTheme.border),
                        ),
                        child: Text(q.toString(), style: const TextStyle(fontSize: 12)),
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
                    'Requests & Quotations',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Customer RFQ inquiries, customized service specifications, and vendor competitive bids',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadRequests,
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
              _filterChip('All Inquiries', ''),
              _filterChip('Open', 'open'),
              _filterChip('Quotes Received', 'quoted'),
              _filterChip('Accepted', 'accepted'),
              _filterChip('Closed', 'closed'),
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
                    : _requests.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyStateView(
                              title: 'No quotation requests found',
                              message: 'Inquiries submitted by customers will be visible here.',
                              icon: Icons.request_quote_outlined,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminTheme.surfaceAlt),
                              columns: const [
                                DataColumn(label: Text('Inquiry Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Bids', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _requests.map((req) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(req.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(req.customerName ?? req.customerId)),
                                    DataCell(Text(req.categoryName ?? '—')),
                                    DataCell(AdminBadge(label: req.status.toUpperCase(), status: req.status)),
                                    DataCell(Text('${req.quotations.length}')),
                                    DataCell(Text(req.createdAt.length >= 10 ? req.createdAt.substring(0, 10) : req.createdAt)),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 18),
                                        tooltip: 'Inspect Request & Bids',
                                        color: AdminTheme.pine700,
                                        onPressed: () => _inspectRequest(req),
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
        _loadRequests();
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
