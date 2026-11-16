import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';
import '../screens/order_detail_sheet.dart';
import '../screens/request_detail_sheet.dart';
import '../widgets/status_badge.dart';

/// My Activity tab: Distinctly separates Scheduled Bookings from Custom Quotation Requests.
class ActivityTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const ActivityTab({super.key, this.onOpenNotifications});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _orderFilter = 'All';
  String _requestFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      appBar: AppBar(
        title: const Text('My Activity'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: AppTheme.forestSlate, size: 20),
            ),
            onPressed: widget.onOpenNotifications,
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: AppTheme.softShadow,
              ),
              labelColor: AppTheme.forestSlate,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Bookings (Scheduled)'),
                Tab(text: 'Custom Requests (Bids)'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(),
          _buildRequestsList(),
        ],
      ),
    );
  }

  // -------------------------
  // BOOKINGS SECTION
  // -------------------------
  Widget _buildOrdersList() {
    final orderFilterOptions = [
      'All',
      'Pending',
      'Accepted',
      'In Progress',
      'Completed',
      'Cancelled'
    ];

    final filteredOrders = OrderRecord.sampleOrders.where((o) {
      if (_orderFilter == 'All') return true;
      if (_orderFilter == 'Pending') {
        return o.status == OrderStatus.pendingConfirmation;
      }
      if (_orderFilter == 'Accepted') return o.status == OrderStatus.accepted;
      if (_orderFilter == 'In Progress') {
        return o.status == OrderStatus.inProgress;
      }
      if (_orderFilter == 'Completed') return o.status == OrderStatus.completed;
      if (_orderFilter == 'Cancelled') return o.status == OrderStatus.cancelled;
      return true;
    }).toList();

    return Column(
      children: [
        // Sub-filter chips
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: orderFilterOptions.length,
            itemBuilder: (context, index) {
              final opt = orderFilterOptions[index];
              final isSelected = _orderFilter == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(
                    opt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.pineGreen
                          : AppTheme.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.pineGreenLight,
                  backgroundColor: AppTheme.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.pineGreen
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    setState(() => _orderFilter = opt);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filteredOrders.isEmpty
              ? _buildEmptyState(
                  icon: Icons.calendar_today_rounded,
                  title: "You haven't booked any services yet.",
                  message: 'Browse services and book verified professionals.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderRecord order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => OrderDetailSheet(order: order),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.id,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  StatusBadge.fromOrderStatus(order.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.serviceTitle,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: AppTheme.surfaceMuted,
                    child: Text(
                      order.providerInitials,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.forestSlate,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.providerName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${order.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.pineGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Track Details →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.pineGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------
  // CUSTOM REQUESTS SECTION
  // -------------------------
  Widget _buildRequestsList() {
    final requestFilterOptions = [
      'All',
      'Submitted',
      'Quotes Received',
      'Accepted',
      'Closed'
    ];

    final filteredRequests = RequestRecord.sampleRequests.where((r) {
      if (_requestFilter == 'All') return true;
      if (_requestFilter == 'Submitted') {
        return r.status == RequestStatus.submitted;
      }
      if (_requestFilter == 'Quotes Received') {
        return r.status == RequestStatus.quoteReceived;
      }
      if (_requestFilter == 'Accepted') {
        return r.status == RequestStatus.accepted;
      }
      if (_requestFilter == 'Closed') {
        return r.status == RequestStatus.completedOrClosed;
      }
      return true;
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: requestFilterOptions.length,
            itemBuilder: (context, index) {
              final opt = requestFilterOptions[index];
              final isSelected = _requestFilter == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(
                    opt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.pineGreen
                          : AppTheme.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.pineGreenLight,
                  backgroundColor: AppTheme.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.pineGreen
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    setState(() => _requestFilter = opt);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filteredRequests.isEmpty
              ? _buildEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: "You haven't created any requests yet.",
                  message:
                      'Post a custom service request to receive quotes from providers.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = filteredRequests[index];
                    return _buildRequestCard(req);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(RequestRecord req) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => RequestDetailSheet(request: req),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req.id,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  StatusBadge.fromRequestStatus(req.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                req.title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                req.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSage,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt_rounded,
                            size: 14, color: AppTheme.pineGreen),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${req.proposals.length} Proposals',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.pineGreen,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Budget: ₹${req.budgetEstimate.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
