import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dodo_universe_admin/core/models.dart';
import 'package:dodo_universe_admin/widgets/admin_badge.dart';
import 'package:dodo_universe_admin/widgets/empty_state_view.dart';
import 'package:dodo_universe_admin/widgets/admin_sidebar.dart';
import 'package:dodo_universe_admin/core/auth_state.dart';
import 'package:dodo_universe_admin/screens/login_screen.dart';

void main() {
  group('Admin Models & Deserialization Tests', () {
    test('AdminUser deserializes correctly', () {
      final json = {
        'id': 'adm_123',
        'email': 'admin@dodouniverse.com',
        'phone': '9876543210',
        'full_name': 'Super Admin',
        'role': 'super_admin',
        'is_active': true,
        'created_at': '2026-11-17T00:00:00Z',
      };
      final admin = AdminUser.fromJson(json);
      expect(admin.id, 'adm_123');
      expect(admin.email, 'admin@dodouniverse.com');
      expect(admin.role, 'super_admin');
      expect(admin.isActive, true);
    });

    test('DashboardMetrics enforces zero fake data defaults', () {
      final json = <String, dynamic>{};
      final metrics = DashboardMetrics.fromJson(json);
      expect(metrics.totalPeople, 0);
      expect(metrics.activeVendors, 0);
      expect(metrics.pendingVendorApplications, 0);
      expect(metrics.totalServices, 0);
      expect(metrics.totalListings, 0);
      expect(metrics.totalOrders, 0);
      expect(metrics.pendingOrders, 0);
      expect(metrics.totalPaymentVolume, 0.0);
      expect(metrics.recentActivity, isEmpty);
    });

    test('ServiceCategoryItem recursive tree parsing', () {
      final json = {
        'id': 'cat_root',
        'name': 'Events & Weddings',
        'slug': 'events-weddings',
        'category_type': 'container',
        'allow_listings': false,
        'is_active': true,
        'children': [
          {
            'id': 'cat_sub',
            'parent_id': 'cat_root',
            'name': 'Photography',
            'slug': 'photography',
            'category_type': 'bookable_service',
            'allow_listings': true,
            'is_active': true,
          }
        ]
      };
      final cat = ServiceCategoryItem.fromJson(json);
      expect(cat.id, 'cat_root');
      expect(cat.children.length, 1);
      expect(cat.children.first.name, 'Photography');
      expect(cat.children.first.allowListings, true);
      expect(cat.children.first.categoryType, 'bookable_service');
    });
  });

  group('Admin Widgets Tests', () {
    testWidgets('AdminBadge renders semantic status text and color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminBadge(label: 'ACTIVE', status: 'active'),
          ),
        ),
      );
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('EmptyStateView renders title, message, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              title: 'No records found',
              message: 'Database is currently empty for this filter.',
              icon: Icons.inbox,
            ),
          ),
        ),
      );
      expect(find.text('No records found'), findsOneWidget);
      expect(find.text('Database is currently empty for this filter.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('AdminSidebar renders navigation items in web viewport', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AdminModule selected = AdminModule.dashboard;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSidebar(
              currentModule: selected,
              userRole: 'super_admin',
              onSelectModule: (m) => selected = m,
            ),
          ),
        ),
      );
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('People Management'), findsOneWidget);
      expect(find.text('Vendor Applications'), findsOneWidget);
      expect(find.text('Services & Categories'), findsOneWidget);
      expect(find.text('Dynamic Form Builder'), findsOneWidget);
      expect(find.text('Products & Listings'), findsOneWidget);
      expect(find.text('Bookings & Orders'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('LoginScreen renders identifier and password inputs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authState = AdminAuthState();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authState: authState),
        ),
      );
      expect(find.text('DODO Universe'), findsOneWidget);
      expect(find.text('ADMINISTRATIVE ACCESS PORTAL'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
