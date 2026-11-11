import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/auth/auth_service.dart';
import 'package:dodo_universe/core/theme/app_theme.dart';
import 'package:dodo_universe/core/widgets/custom_text_field.dart';
import 'package:dodo_universe/core/widgets/primary_button.dart';
import 'package:dodo_universe/screens/auth/login_screen.dart';
import 'package:dodo_universe/screens/auth/register_screen.dart';
import 'package:dodo_universe/screens/auth/verify_mobile_screen.dart';

class FakeLoginAuthService implements IAuthService {
  bool sendLoginCalled = false;
  String? sentPhone;
  AuthResult loginResult = const AuthResult.success();

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async {
    sendLoginCalled = true;
    sentPhone = mobileNumber;
    return loginResult;
  }

  @override
  Future<AuthResult> attachEmail({required String email}) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async =>
      const AuthResult.success();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async =>
      const AuthResult.success();

  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async => true;

  @override
  bool isRegistrationComplete([User? user]) => true;
}

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  group('LoginScreen', () {
    testWidgets('renders login UI elements and header correctly',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const LoginScreen(),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('validates required and 10-digit mobile number',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const LoginScreen(),
        ),
      );

      // Attempt submit without filling
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your mobile number'), findsOneWidget);

      // Enter short number (< 10 digits)
      final phoneField = find.descendant(
        of: find.byType(CustomTextField),
        matching: find.byType(TextField),
      );
      await tester.enterText(phoneField, '12345');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid 10-digit mobile number'),
        findsOneWidget,
      );
    });

    testWidgets(
        'submitting valid mobile number triggers login and navigates to VerifyMobileScreen',
        (tester) async {
      final fakeAuth = FakeLoginAuthService();

      await tester.pumpWidget(
        buildTestableWidget(
          LoginScreen(authService: fakeAuth),
        ),
      );

      final phoneField = find.descendant(
        of: find.byType(CustomTextField),
        matching: find.byType(TextField),
      );
      await tester.enterText(phoneField, '9876543210');

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(fakeAuth.sendLoginCalled, isTrue);
      expect(fakeAuth.sentPhone, equals('9876543210'));
      expect(find.byType(VerifyMobileScreen), findsOneWidget);
      expect(find.text('Login'), findsOneWidget); // Step indicator badge
    });

    testWidgets('displays error message when login OTP sending fails',
        (tester) async {
      final fakeAuth = FakeLoginAuthService()
        ..loginResult = const AuthResult.failure(
          'No existing account found with this mobile number. Please register first.',
        );

      await tester.pumpWidget(
        buildTestableWidget(
          LoginScreen(authService: fakeAuth),
        ),
      );

      final phoneField = find.descendant(
        of: find.byType(CustomTextField),
        matching: find.byType(TextField),
      );
      await tester.enterText(phoneField, '9876543210');

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyMobileScreen), findsNothing);
      expect(
        find.text(
          'No existing account found with this mobile number. Please register first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Create Account button navigates to RegisterScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const LoginScreen(),
        ),
      );

      await tester.ensureVisible(find.text('Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
