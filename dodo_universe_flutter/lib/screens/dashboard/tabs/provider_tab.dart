import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';

/// Provider Hub: The Provider Studio dashboard to offer services, set availability & bid on client requests.
class ProviderTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const ProviderTab({super.key, this.onOpenNotifications});

  @override
  State<ProviderTab> createState() => _ProviderTabState();
}

class _ProviderTabState extends State<ProviderTab> {
  bool _isAcceptingOrders = true;

  // Provider's own active service offerings
  final List<Map<String, dynamic>> _myServices = [];

  // Open client requests waiting for bids
  final List<RequestRecord> _openRequestsToBid = [];

  void _showAddServiceDialog() {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text(
          'Add New Service Offering',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Title',
                hintText: 'e.g. 3D Model Printing or Python Tutoring',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Base Rate (₹)',
                hintText: 'e.g. 450',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              decoration: const InputDecoration(
                labelText: 'Estimated Turnaround',
                hintText: 'e.g. 1 Hour or Same Day',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  _myServices.add({
                    'title': titleCtrl.text.trim(),
                    'price': int.tryParse(priceCtrl.text) ?? 500,
                    'duration': durationCtrl.text.trim().isNotEmpty
                        ? durationCtrl.text.trim()
                        : '1 hour',
                    'isActive': true,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('New service offering published!')),
                );
              }
            },
            child: const Text('Publish Service'),
          ),
        ],
      ),
    );
  }

  void _showSubmitProposalModal(RequestRecord req) {
    final priceCtrl =
        TextEditingController(text: req.budgetEstimate.toStringAsFixed(0));
    final turnaroundCtrl = TextEditingController(text: 'Tomorrow afternoon');
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Submit Quotation Proposal',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Propose your rate and turnaround time for "${req.title}".',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Proposed Price (₹)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: turnaroundCtrl,
                decoration: const InputDecoration(
                  labelText: 'Turnaround Time',
                  hintText: 'e.g. Within 24 hours',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Proposal Note / Included Items',
                  hintText:
                      'Describe your tools, background, and how you will complete this request...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.forestSlate,
                        content: Text(
                          'Quotation proposal submitted to client!',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.surfaceWhite),
                        ),
                      ),
                    );
                  },
                  child: const Text('Send Quotation to Client'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvasColor,
      appBar: AppBar(
        title: const Text('Provider Studio'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Studio Verification & Earnings Card
            _buildStudioHeroCard(),
            const SizedBox(height: 22),

            // 2. Availability Switch Card
            _buildAvailabilityCard(),
            const SizedBox(height: 24),

            // 3. Client Requests Open for Bidding
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Client Requests to Bid',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warmOchreLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '${_openRequestsToBid.length} Available',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warmOchre,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildOpenRequestsList(),
            const SizedBox(height: 28),

            // 4. Managed Services
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Active Services',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Service'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildManagedServicesList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.forestSlate,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.pineGreen,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 14, color: AppTheme.surfaceWhite),
                        const SizedBox(width: 5),
                        Text(
                          'Provider Balance',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.surfaceWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                'New Provider',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSubtle,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'No earnings yet',
            style: GoogleFonts.outfit(
              color: AppTheme.surfaceWhite,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Complete client bookings & requests to view settlements',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSubtle,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceMuted,
                    foregroundColor: AppTheme.textMuted,
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('No Payout Balance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAcceptingOrders
                      ? AppTheme.pineGreen
                      : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAcceptingOrders
                        ? 'Accepting New Client Jobs'
                        : 'Studio Paused',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _isAcceptingOrders
                        ? 'Your profile is publicly bookable'
                        : 'Currently not taking new requests',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: _isAcceptingOrders,
            activeTrackColor: AppTheme.pineGreen,
            onChanged: (val) => setState(() => _isAcceptingOrders = val),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenRequestsList() {
    if (_openRequestsToBid.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: AppTheme.softShadow,
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 36, color: AppTheme.textSubtle),
              const SizedBox(height: 10),
              Text(
                'No orders received yet.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Broadcasted customer requests and incoming direct bookings will appear here.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted,
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _openRequestsToBid.map((req) {
        return Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 12),
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
                    req.category,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.pineGreen,
                    ),
                  ),
                  Text(
                    'Client Budget: ₹${req.budgetEstimate.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSubmitProposalModal(req),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Submit Quotation Proposal'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManagedServicesList() {
    if (_myServices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: AppTheme.softShadow,
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.handyman_outlined,
                  size: 36, color: AppTheme.textSubtle),
              const SizedBox(height: 10),
              Text(
                "You haven't added any services yet.",
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add offerings with pricing and duration to start receiving bookings.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted,
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myServices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = _myServices[index];
        final bool isActive = s['isActive'] == true;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${s['price']} • ${s['duration']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeTrackColor: AppTheme.pineGreen,
                onChanged: (val) {
                  setState(() {
                    s['isActive'] = val;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
