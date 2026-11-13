import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/auth/auth_service.dart';
import 'package:dodo_universe/main.dart';
import 'package:dodo_universe/screens/auth/auth_gate.dart';
import 'package:dodo_universe/screens/auth/registration_success_screen.dart';
import 'package:dodo_universe/screens/auth/verify_email_screen.dart';
import 'package:dodo_universe/screens/auth/welcome_screen.dart';
import 'package:dodo_universe/screens/home_screen.dart';

class GateTestMockAuth implements IAuthService {
  User? _currentUser;
  Session? _currentSession;
  bool signOutCalled = false;

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  GateTestMockAuth({User? initialUser, Session? initialSession})
      : _currentUser = initialUser,
        _currentSession = initialSession;

  void emitAuthState(AuthState state) {
    if (state.session != null) {
      _currentSession = state.session;
      _currentUser = state.session!.user;
    } else if (state.event == AuthChangeEvent.signedOut) {
      _currentSession = null;
      _currentUser = null;
    }
    _authStateController.add(state);
  }

  void setCurrentUser(User? user) {
    _currentUser = user;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => _currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  bool shouldFailProfileQuery = false;
  bool isMissingProfile = false;
  bool? trustedCompletionOverride;

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async {
    if (shouldFailProfileQuery) {
      throw const SocketException('Simulated network failure on profile query');
    }
    if (isMissingProfile) {
      return false;
    }
    if (trustedCompletionOverride != null) {
      return trustedCompletionOverride!;
    }
    return isRegistrationComplete(user);
  }

  @override
  bool isRegistrationComplete([User? user]) {
    final target = user ?? _currentUser;
    if (target == null) return false;
    final hasPhone = target.phoneConfirmedAt != null ||
        (target.phone != null && target.phone!.isNotEmpty);
    final hasEmail = target.email != null && target.email!.isNotEmpty;
    final hasConfirmedEmail = target.emailConfirmedAt != null;
    return hasPhone && hasEmail && hasConfirmedEmail;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _currentUser = null;
    _currentSession = null;
    emitAuthState(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async =>
      AuthResult.success(user: _currentUser, session: _currentSession);

  @override
  Future<AuthResult> attachEmail({required String email}) async =>
      AuthResult.success(user: _currentUser);

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    return AuthResult.success(user: _currentUser, session: _currentSession);
  }

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async =>
      AuthResult.success(user: _currentUser, session: _currentSession);
}

User createTestUser({
  String id = 'user-123',
  String phone = '+919876543210',
  String? email = 'rahul@example.com',
  String? phoneConfirmedAt = '2026-11-09T00:00:00Z',
  String? emailConfirmedAt = '2026-11-09T00:00:00Z',
  Map<String, dynamic>? userMetadata,
}) {
  return User.fromJson(<String, dynamic>{
    'id': id,
    'app_metadata': <String, dynamic>{},
    'user_metadata':
        userMetadata ?? <String, dynamic>{'full_name': 'Rahul Sharma'},
    'aud': 'authenticated',
    'phone': phone,
    'phone_confirmed_at': phoneConfirmedAt,
    'email': email,
    'email_confirmed_at': emailConfirmedAt,
    'created_at': '2026-11-09T00:00:00Z',
  })!;
}

Session createTestSession(User user) {
  return Session.fromJson(<String, dynamic>{
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'user': <String, dynamic>{
      'id': user.id,
      'app_metadata': <String, dynamic>{},
      'user_metadata': user.userMetadata ?? <String, dynamic>{},
      'aud': 'authenticated',
      'phone': user.phone,
      'phone_confirmed_at': user.phoneConfirmedAt,
      'email': user.email,
      'email_confirmed_at': user.emailConfirmedAt,
      'created_at': user.createdAt,
    },
  })!;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AuthGate - Step 7 Authentication Integration Tests', () {
    testWidgets('1. App startup without a session shows WelcomeScreen',
        (tester) async {
      final mockAuth = GateTestMockAuth(initialUser: null);

      await tester.pumpWidget(DodoUniverseApp(authService: mockAuth));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('DODO Universe'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('2. App startup with valid completed session shows HomeScreen',
        (tester) async {
      final completedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: completedUser,
        initialSession: createTestSession(completedUser),
      );

      await tester.pumpWidget(DodoUniverseApp(authService: mockAuth));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets(
        '3. App startup with incomplete registration resumes VerifyEmailScreen',
        (tester) async {
      final incompleteUser = createTestUser(
        email: 'rahul@example.com',
        emailConfirmedAt: null, // Phone verified, email not confirmed
      );
      final mockAuth = GateTestMockAuth(
        initialUser: incompleteUser,
        initialSession: createTestSession(incompleteUser),
      );

      await tester.pumpWidget(DodoUniverseApp(authService: mockAuth));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets(
        '4. Session restoration: initial loading transitions to destination',
        (tester) async {
      final completedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: completedUser,
        initialSession: createTestSession(completedUser),
      );

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(
          authService: mockAuth,
          initialLoading: true,
        ),
      ));

      // Initial frame renders loading indicator
      expect(
          find.byKey(const Key('auth_gate_loading_indicator')), findsOneWidget);

      // Restore session event
      mockAuth.emitAuthState(
        AuthState(AuthChangeEvent.signedIn, createTestSession(completedUser)),
      );
      await tester.pumpAndSettle();

      // Settled frame displays resolved destination
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        '5. Logout from HomeScreen signs out and returns to WelcomeScreen',
        (tester) async {
      final completedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: completedUser,
        initialSession: createTestSession(completedUser),
      );

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap logout button in HomeScreen AppBar
      final logoutBtn = find.byKey(const Key('phase0_logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(mockAuth.signOutCalled, isTrue);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
        '6. Session expiration: auth state signedOut navigates to WelcomeScreen',
        (tester) async {
      final completedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: completedUser,
        initialSession: createTestSession(completedUser),
      );

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Simulate token expiration / refresh failure
      mockAuth.emitAuthState(
        const AuthState(AuthChangeEvent.signedOut, null),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('7. Auth state change to signedIn navigates to HomeScreen',
        (tester) async {
      final mockAuth = GateTestMockAuth(initialUser: null);

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Emit signed in event with completed user
      final user = createTestUser();
      mockAuth.emitAuthState(
        AuthState(AuthChangeEvent.signedIn, createTestSession(user)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        '8. Auth state change to signedIn with incomplete user navigates to VerifyEmailScreen',
        (tester) async {
      final mockAuth = GateTestMockAuth(initialUser: null);

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Emit signed in event with incomplete user
      final user = createTestUser(emailConfirmedAt: null);
      mockAuth.emitAuthState(
        AuthState(AuthChangeEvent.signedIn, createTestSession(user)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets(
        '9. Completing email verification on resumed screen advances to RegistrationSuccessScreen',
        (tester) async {
      final incompleteUser = createTestUser(emailConfirmedAt: null);
      final mockAuth = GateTestMockAuth(
        initialUser: incompleteUser,
        initialSession: createTestSession(incompleteUser),
      );

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);

      // Enter 6-digit OTP
      final otpField = find.byType(TextField).first;
      await tester.enterText(otpField, '123456');
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
    });

    testWidgets('10. Security: back navigation blocked after logout',
        (tester) async {
      final completedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: completedUser,
        initialSession: createTestSession(completedUser),
      );

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      // Logout
      await tester.tap(find.byKey(const Key('phase0_logout_button')));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Verify that there are no routes to pop back to
      final nav = Navigator.of(tester.element(find.byType(WelcomeScreen)));
      expect(nav.canPop(), isFalse);
    });

    testWidgets(
        '11. AuthGate with is_registration_complete = false, even when phone and email are confirmed, routes to VerifyEmailScreen',
        (tester) async {
      // User has phoneConfirmedAt AND emailConfirmedAt, but trusted profile has is_registration_complete = false
      final confirmedUser = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: confirmedUser,
        initialSession: createTestSession(confirmedUser),
      );
      mockAuth.trustedCompletionOverride = false; // Database says NOT complete

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      // Must NOT route to HomeScreen; must route to VerifyEmailScreen
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets(
        '12. AuthGate with trusted completion status true routes to HomeScreen',
        (tester) async {
      final user = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: user,
        initialSession: createTestSession(user),
      );
      mockAuth.trustedCompletionOverride = true; // Database confirms complete

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(VerifyEmailScreen), findsNothing);
    });

    testWidgets(
        '13. Profile query failure displays safe error UI and allows retry',
        (tester) async {
      final user = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: user,
        initialSession: createTestSession(user),
      );
      mockAuth.shouldFailProfileQuery = true; // Simulate network failure

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      // Must display safe error screen, never HomeScreen
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.byKey(const Key('auth_gate_retry_button')), findsOneWidget);

      // Now recover network and tap Retry
      mockAuth.shouldFailProfileQuery = false;
      await tester.tap(find.byKey(const Key('auth_gate_retry_button')));
      await tester.pumpAndSettle();

      // Resolves to HomeScreen safely
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('14. Missing profile record prevents access to HomeScreen',
        (tester) async {
      final user = createTestUser();
      final mockAuth = GateTestMockAuth(
        initialUser: user,
        initialSession: createTestSession(user),
      );
      mockAuth.isMissingProfile = true; // Missing profile record

      await tester.pumpWidget(MaterialApp(
        home: AuthGate(authService: mockAuth),
      ));
      await tester.pumpAndSettle();

      // Must NOT show HomeScreen
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });
  });
}
