import 'package:flutter/material.dart';
import '../core/theme.dart';

enum AdminModule {
  dashboard,
  people,
  vendorApplications,
  servicesCategories,
  formBuilder,
  listings,
  orders,
  requestsQuotes,
  paymentsCommission,
  notifications,
  reviewsReports,
  adminManagement,
  auditLogs,
  settings,
}

class AdminSidebar extends StatelessWidget {
  final AdminModule currentModule;
  final ValueChanged<AdminModule> onSelectModule;
  final String? userRole;

  const AdminSidebar({
    super.key,
    required this.currentModule,
    required this.onSelectModule,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _Item(AdminModule.dashboard, 'Dashboard', Icons.dashboard_outlined),
      _Item(AdminModule.people, 'People Management', Icons.people_outline),
      _Item(AdminModule.vendorApplications, 'Vendor Applications', Icons.verified_user_outlined),
      _Item(AdminModule.servicesCategories, 'Services & Categories', Icons.layers_outlined),
      _Item(AdminModule.formBuilder, 'Dynamic Form Builder', Icons.dynamic_form_outlined),
      _Item(AdminModule.listings, 'Products & Listings', Icons.inventory_2_outlined),
      _Item(AdminModule.orders, 'Bookings & Orders', Icons.shopping_bag_outlined),
      _Item(AdminModule.requestsQuotes, 'Requests & Quotations', Icons.request_quote_outlined),
      _Item(AdminModule.paymentsCommission, 'Payments & Commission', Icons.payments_outlined),
      _Item(AdminModule.notifications, 'Notifications', Icons.notifications_none_outlined),
      _Item(AdminModule.reviewsReports, 'Reviews & Reports', Icons.star_border),
      _Item(AdminModule.adminManagement, 'Admin Management', Icons.admin_panel_settings_outlined, superOnly: true),
      _Item(AdminModule.auditLogs, 'Audit Logs', Icons.history),
      _Item(AdminModule.settings, 'Settings', Icons.tune),
    ];

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AdminTheme.border)),
      ),
      child: Column(
        children: [
          // Header / Logo
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AdminTheme.pine700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DODO Universe',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AdminTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'ADMIN CONSOLE',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          color: AdminTheme.pine700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 8, top: 4),
                  child: Text(
                    'PLATFORM OPERATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ...menuItems.map((item) {
                  if (item.superOnly && userRole != 'super_admin') {
                    return const SizedBox.shrink();
                  }
                  final isSelected = currentModule == item.module;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: isSelected ? AdminTheme.pine50 : null,
                        leading: Icon(
                          item.icon,
                          size: 18,
                          color: isSelected ? AdminTheme.pine700 : AdminTheme.textSecondary,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AdminTheme.pine700 : AdminTheme.textPrimary,
                          ),
                        ),
                        onTap: () => onSelectModule(item.module),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AdminTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Admin v1.0.0 (Flutter)',
                    style: TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final AdminModule module;
  final String label;
  final IconData icon;
  final bool superOnly;

  _Item(this.module, this.label, this.icon, {this.superOnly = false});
}
