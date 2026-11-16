import 'package:dodo_universe/core/auth/dev_auth_service.dart';
import 'package:dodo_universe/screens/dashboard/dashboard_screen.dart';
import 'package:dodo_universe/screens/dashboard/models/dashboard_models.dart';
import 'package:dodo_universe/screens/dashboard/screens/notifications_screen.dart';
import 'package:dodo_universe/screens/dashboard/screens/order_detail_sheet.dart';
import 'package:dodo_universe/screens/dashboard/screens/provider_detail_sheet.dart';
import 'package:dodo_universe/screens/dashboard/screens/request_detail_sheet.dart';
import 'package:dodo_universe/screens/dashboard/tabs/activity_tab.dart';
import 'package:dodo_universe/screens/dashboard/tabs/explore_tab.dart';
import 'package:dodo_universe/screens/dashboard/tabs/home_tab.dart';
import 'package:dodo_universe/screens/dashboard/tabs/profile_tab.dart';
import 'package:dodo_universe/screens/dashboard/tabs/provider_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DevAuthService devAuth;

  setUp(() {
    devAuth = DevAuthService();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('DODO Universe Warm Nordic Atelier Dashboard Tests', () {
    testWidgets('1. DashboardScreen renders with Mobile BottomNavigationBar',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(DashboardScreen(authService: devAuth)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Explore'), findsWidgets);
      expect(find.text('My Activity'), findsWidgets);
      expect(find.text('Provider Hub'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
    });

    testWidgets('2. Responsive Tablet layout shows NavigationRail',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          DashboardScreen(authService: devAuth),
          size: const Size(768, 1024),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('3. Responsive Desktop layout shows Fixed Sidebar',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          DashboardScreen(authService: devAuth),
          size: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DODO Universe'), findsOneWidget);
      expect(find.text('Find Services'), findsOneWidget);
      expect(find.text('Provider Hub'), findsOneWidget);
    });

    testWidgets('4. HomeTab renders search bar, actions and categories',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(body: HomeTab(userName: 'Alex')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Alex'), findsOneWidget);
      expect(find.text('Book a Service'), findsOneWidget);
      expect(find.text('Post a Request'), findsOneWidget);
      expect(find.text('Explore Categories'), findsOneWidget);
    });

    testWidgets(
        '5. ExploreTab shows clean empty state when no services are loaded',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ExploreTab()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find Services'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('No services available yet.'), findsOneWidget);
    });

    testWidgets(
        '6. ActivityTab shows clean empty state for bookings & requests',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ActivityTab()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bookings (Scheduled)'), findsOneWidget);
      expect(find.text('Custom Requests (Bids)'), findsOneWidget);
      expect(find.text("You haven't booked any services yet."), findsOneWidget);

      await tester.tap(find.text('Custom Requests (Bids)'));
      await tester.pumpAndSettle();

      expect(
          find.text("You haven't created any requests yet."), findsOneWidget);
    });

    testWidgets(
        '7. ProviderTab displays Studio wallet empty state & availability',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ProviderTab()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Provider Studio'), findsOneWidget);
      expect(find.text('Provider Balance'), findsOneWidget);
      expect(find.text('No earnings yet'), findsOneWidget);
      expect(find.text('No orders received yet.'), findsOneWidget);
      expect(find.text("You haven't added any services yet."), findsOneWidget);
    });

    testWidgets('8. ProfileTab displays user account & settings options',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(ProfileTab(authService: devAuth)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Saved Service Locations'), findsOneWidget);
      expect(find.text('No saved service locations yet.'), findsOneWidget);
      expect(find.text('Preferences & Security'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('9. NotificationsScreen renders empty state when caught up',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const NotificationsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark All Read'), findsOneWidget);
      expect(find.text("You're all caught up."), findsOneWidget);
    });

    testWidgets('10. OrderDetailSheet renders 4-stage life-cycle timeline',
        (tester) async {
      final testOrder = OrderRecord(
        id: 'TEST-ORD-01',
        serviceTitle: 'Test Service Booking',
        providerName: 'Test Provider',
        providerInitials: 'TP',
        category: 'Tech & Electronics',
        amount: 500.0,
        orderDate: DateTime(2026, 11, 1),
        status: OrderStatus.inProgress,
        location: 'Test Location',
      );
      await tester.pumpWidget(
        buildTestableWidget(OrderDetailSheet(order: testOrder)),
      );
      await tester.pumpAndSettle();

      expect(find.text(testOrder.serviceTitle), findsOneWidget);
      expect(find.text('Booking Submitted'), findsOneWidget);
      expect(find.text('Accepted by Provider'), findsOneWidget);
      expect(find.text('In Progress / Service Underway'), findsOneWidget);
      expect(find.text('Completed & Settled'), findsOneWidget);
    });

    testWidgets('11. RequestDetailSheet renders quotations and acceptance',
        (tester) async {
      final testRequest = RequestRecord(
        id: 'TEST-REQ-01',
        title: 'Test Request Title',
        category: 'Design & Engineering',
        description: 'Test Description for Request',
        budgetEstimate: 1000.0,
        createdAt: DateTime(2026, 11, 1),
        status: RequestStatus.quoteReceived,
        proposals: [
          QuoteProposal(
            providerId: 'p1',
            providerName: 'Pro One',
            initials: 'P1',
            rating: 4.9,
            proposedPrice: 950.0,
            turnaroundTime: '2 days',
            note: 'Test Proposal Note',
            submittedAt: DateTime(2026, 11, 2),
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestableWidget(RequestDetailSheet(request: testRequest)),
      );
      await tester.pumpAndSettle();

      expect(find.text(testRequest.title), findsOneWidget);
      expect(find.text('Accept Bid & Hire'), findsWidgets);
    });

    testWidgets(
        '12. ProviderDetailSheet renders profile & standard service menu',
        (tester) async {
      final testProvider = ServiceProvider(
        id: 'p-test',
        name: 'Test Pro Specialist',
        category: 'Tech & Electronics',
        headline: 'Certified Specialist',
        initials: 'TS',
        rating: 4.9,
        reviewCount: 10,
        startingPrice: 300.0,
        location: 'Central Metro',
        isVerified: true,
        availability: 'Available',
        completedJobs: 15,
        bio: 'Professional test bio.',
        servicesOffered: const ['Service A', 'Service B'],
      );
      await tester.pumpWidget(
        buildTestableWidget(ProviderDetailSheet(provider: testProvider)),
      );
      await tester.pumpAndSettle();

      expect(find.text(testProvider.name), findsOneWidget);
      expect(find.text('Standard Service Menu'), findsOneWidget);
      expect(find.text('Book Direct Service'), findsOneWidget);
    });
  });
}
