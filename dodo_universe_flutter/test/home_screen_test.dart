import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/auth/auth_service.dart';
import 'package:dodo_universe/core/theme/app_theme.dart';
import 'package:dodo_universe/screens/auth/auth_gate.dart';
import 'package:dodo_universe/screens/auth/welcome_screen.dart';
import 'package:dodo_universe/screens/home_screen.dart';

class MockHomeScreenAuth implements IAuthService {
  User? _user;
  Session? _session;
  bool signOutCalled = false;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  MockHomeScreenAuth({User? user, Session? session})
      : _user = user,
        _session = session;

  @override
  User? get currentUser => _user;

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _user = null;
    _session = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  bool isRegistrationComplete([User? user]) => true;

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async => true;

  @override
  Future<AuthResult> sendRegistrationMobileOtp(
          {required String fullName,
          required String mobileNumber,
          String? email}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyRegistrationMobileOtp(
          {required String mobileNumber, required String otp}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> attachEmail({required String email}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyEmailOtp(
          {required String email, required String otp}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyLoginOtp(
          {required String mobileNumber, required String otp}) async =>
      const AuthResult.success();
}

User createTestUser({
  String id = 'e9b3a042-491a-4c28-986f-3df15e19f18a',
  String? fullName = 'Yamini Sharma',
  String? phone = '+919876543210',
  String? email = 'yamini@example.com',
}) {
  return User.fromJson(<String, dynamic>{
    'id': id,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
    },
    'aud': 'authenticated',
    'phone': phone,
    'email': email,
    'created_at': '2026-11-12T10:00:00Z',
  })!;
}

void main() {
  group('HomeScreen - Authenticated Dashboard Tests', () {
    testWidgets('1. Displays authenticated user full name, phone, and email',
        (tester) async {
      final user = createTestUser(
        fullName: 'Yamini Sharma',
        phone: '+919876543210',
        email: 'yamini@example.com',
      );
      final auth = MockHomeScreenAuth(user: user);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      // Brand Title
      expect(find.text('DODO Universe'), findsOneWidget);

      // User details
      expect(find.text('Yamini Sharma'),
          findsNWidgets(2)); // Card header & Account details
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('yamini@example.com'), findsOneWidget);

      // Verified badge
      expect(find.text('Verified University Account'), findsOneWidget);
    });

    testWidgets('2. Displays fallbacks when user details are not provided',
        (tester) async {
      final user = createTestUser(
        fullName: null,
        phone: null,
        email: null,
      );
      final auth = MockHomeScreenAuth(user: user);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      // Default fallback name
      expect(find.text('University Member'), findsNWidgets(2));
      // Default fallback phone and email
      expect(find.text('Not provided'), findsNWidgets(2));
    });

    testWidgets(
        '3. Tapping AppBar logout button invokes signOut and redirects to AuthGate',
        (tester) async {
      final user = createTestUser();
      final auth = MockHomeScreenAuth(user: user);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthGate(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap AppBar logout button
      final logoutBtn = find.byKey(const Key('home_logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(auth.signOutCalled, isTrue);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets(
        '4. Tapping body logout button invokes signOut and redirects to AuthGate',
        (tester) async {
      final user = createTestUser();
      final auth = MockHomeScreenAuth(user: user);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthGate(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap body logout button
      final bodyLogoutBtn =
          find.byKey(const Key('home_logout_outlined_button'));
      expect(bodyLogoutBtn, findsOneWidget);
      await tester.ensureVisible(bodyLogoutBtn);
      await tester.tap(bodyLogoutBtn);
      await tester.pumpAndSettle();

      expect(auth.signOutCalled, isTrue);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
