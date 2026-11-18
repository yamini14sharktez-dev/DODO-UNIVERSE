import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/theme.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_sidebar.dart';
import 'admin_management_screen.dart';
import 'audit_logs_screen.dart';
import 'dashboard_screen.dart';
import 'form_builder_screen.dart';
import 'listings_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'payments_screen.dart';
import 'people_screen.dart';
import 'requests_quotes_screen.dart';
import 'reviews_reports_screen.dart';
import 'services_categories_screen.dart';
import 'settings_screen.dart';
import 'vendor_applications_screen.dart';

class AdminShellScreen extends StatefulWidget {
  final AdminAuthState authState;

  const AdminShellScreen({super.key, required this.authState});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminModule _currentModule = AdminModule.dashboard;

  String _getModuleTitle(AdminModule m) {
    switch (m) {
      case AdminModule.dashboard:
        return 'Executive Dashboard';
      case AdminModule.people:
        return 'People & Accounts Management';
      case AdminModule.vendorApplications:
        return 'Vendor Verification & Applications';
      case AdminModule.servicesCategories:
        return 'Service Taxonomy & Categories';
      case AdminModule.formBuilder:
        return 'Dynamic Service Form Builder';
      case AdminModule.listings:
        return 'Catalog Products & Listings';
      case AdminModule.orders:
        return 'Platform Orders & Bookings';
      case AdminModule.requestsQuotes:
        return 'Customer Quotation Requests';
      case AdminModule.paymentsCommission:
        return 'Finance & Commission Control';
      case AdminModule.notifications:
        return 'Platform Announcements & Alerts';
      case AdminModule.reviewsReports:
        return 'Reviews, Moderation & Reports';
      case AdminModule.adminManagement:
        return 'Administrator Personnel Management';
      case AdminModule.auditLogs:
        return 'System Audit Trail & Logs';
      case AdminModule.settings:
        return 'Platform & Security Settings';
    }
  }

  Widget _buildModuleBody(AdminModule m) {
    switch (m) {
      case AdminModule.dashboard:
        return const DashboardScreen();
      case AdminModule.people:
        return const PeopleScreen();
      case AdminModule.vendorApplications:
        return const VendorApplicationsScreen();
      case AdminModule.servicesCategories:
        return const ServicesCategoriesScreen();
      case AdminModule.formBuilder:
        return const FormBuilderScreen();
      case AdminModule.listings:
        return const ListingsScreen();
      case AdminModule.orders:
        return const OrdersScreen();
      case AdminModule.requestsQuotes:
        return const RequestsQuotesScreen();
      case AdminModule.paymentsCommission:
        return const PaymentsScreen();
      case AdminModule.notifications:
        return const NotificationsScreen();
      case AdminModule.reviewsReports:
        return const ReviewsReportsScreen();
      case AdminModule.adminManagement:
        return const AdminManagementScreen();
      case AdminModule.auditLogs:
        return const AuditLogsScreen();
      case AdminModule.settings:
        return const SettingsScreen();
    }
  }

  Future<void> _logout() async {
    await widget.authState.logout();
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = widget.authState.currentAdmin ?? AdminApiClient().currentAdmin;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: Row(
        children: [
          // Fixed Sidebar on the left
          AdminSidebar(
            currentModule: _currentModule,
            userRole: currentAdmin?.role,
            onSelectModule: (m) => setState(() => _currentModule = m),
          ),

          // Main Screen Area
          Expanded(
            child: Column(
              children: [
                // Top Header
                AdminHeader(
                  title: _getModuleTitle(_currentModule),
                  admin: currentAdmin,
                  onLogout: _logout,
                ),

                // Active Module Content
                Expanded(
                  child: Container(
                    color: AdminTheme.background,
                    child: _buildModuleBody(_currentModule),
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
