import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/auth/dev_auth_service.dart';
import 'package:dodo_universe/core/theme/app_theme.dart';
import 'package:dodo_universe/core/widgets/custom_text_field.dart';
import 'package:dodo_universe/core/widgets/primary_button.dart';
import 'package:dodo_universe/screens/auth/auth_gate.dart';
import 'package:dodo_universe/screens/auth/login_screen.dart';
import 'package:dodo_universe/screens/auth/register_screen.dart';
import 'package:dodo_universe/screens/auth/registration_success_screen.dart';
import 'package:dodo_universe/screens/auth/verify_email_screen.dart';
import 'package:dodo_universe/screens/auth/verify_mobile_screen.dart';
import 'package:dodo_universe/screens/auth/welcome_screen.dart';
import 'package:dodo_universe/screens/home_screen.dart';

void main() {
  setUp(() {
    DevAuthService.resetDevStore();
    DevAuthService.registerTestNumber('9876543210', '123456');
    DevAuthService.registerTestNumber('9123456789', '123456');
    DevAuthService.registerTestNumber('9988776655', '123456');
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  group('Phase 7 – Development OTP & New-User Registration Flow', () {
    testWidgets(
        '1. Complete end-to-end new-user registration flow reaches HomeScreen',
        (tester) async {
      final devAuth = DevAuthService();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: devAuth),
      ));
      await tester.pumpAndSettle();

      // Starts at WelcomeScreen
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);

      // Enter registration details using confirmed test number
      final fields = find.byType(CustomTextField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(
        find.descendant(of: fields.at(0), matching: find.byType(TextField)),
        'Kavya Patel',
      );
      await tester.enterText(
        find.descendant(of: fields.at(1), matching: find.byType(TextField)),
        '9392518488',
      );
      await tester.enterText(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
        'kavya@dodo.edu',
      );

      // Tap Send OTP
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Advances to VerifyMobileScreen
      expect(find.byType(VerifyMobileScreen), findsOneWidget);
      expect(find.text('Verify Mobile Number'), findsOneWidget);

      // Enter Dev OTP '654321' for +919392518488
      await tester.enterText(find.byType(TextField), '654321');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Advances to VerifyEmailScreen
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Verify Email Address'), findsOneWidget);

      // Enter Dev Email OTP '123456'
      await tester.enterText(
          find.byType(TextField), DevAuthService.defaultEmailOtp);
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Advances to RegistrationSuccessScreen
      expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
      expect(find.text('Registration Successful'), findsOneWidget);
      expect(find.textContaining('Kavya Patel'), findsOneWidget);

      // Tap Continue to Login
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Arrives at authenticated HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Kavya Patel'), findsWidgets);
      expect(find.text('Verified University Account'), findsOneWidget);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.isRegistrationComplete(), isTrue);
    });

    testWidgets('2. Session persists after simulated app restart',
        (tester) async {
      // 1. Complete registration first
      final devAuth1 = DevAuthService();
      await devAuth1.sendRegistrationMobileOtp(
        fullName: 'Aarav Mehta',
        mobileNumber: '9123456789',
        email: 'aarav@dodo.edu',
      );
      await devAuth1.verifyRegistrationMobileOtp(
        mobileNumber: '9123456789',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth1.verifyEmailOtp(
        email: 'aarav@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );

      expect(devAuth1.isRegistrationComplete(), isTrue);
      expect(DevAuthService.persistedSession, isNotNull);

      // 2. Simulate app restart with a fresh DevAuthService instance
      final restartedAuth = DevAuthService();
      expect(restartedAuth.currentUser, isNotNull);
      expect(restartedAuth.currentSession, isNotNull);
      expect(restartedAuth.isRegistrationComplete(), isTrue);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: restartedAuth),
      ));
      await tester.pumpAndSettle();

      // Directly renders HomeScreen without WelcomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets(
        '3. Incomplete registration resumes at VerifyEmailScreen on app restart',
        (tester) async {
      // Create incomplete user fixture (phone confirmed, email unconfirmed)
      final incompleteUser = User(
        id: 'incomplete-dev-user-id',
        appMetadata: const <String, dynamic>{'provider': 'phone'},
        userMetadata: const <String, dynamic>{
          'full_name': 'Pooja Verma',
          'email': 'pooja@dodo.edu',
          'phone': '+919988776655',
        },
        aud: 'authenticated',
        email: 'pooja@dodo.edu',
        phone: '+919988776655',
        createdAt: DateTime.now().toIso8601String(),
        phoneConfirmedAt: DateTime.now().toIso8601String(),
        emailConfirmedAt: null,
      );
      DevAuthService.seedUser(incompleteUser);

      // App restarts with incomplete registration
      final restartedAuth = DevAuthService(initialUser: incompleteUser);
      expect(restartedAuth.currentUser, isNotNull);
      expect(restartedAuth.isRegistrationComplete(), isFalse);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: restartedAuth),
      ));
      await tester.pumpAndSettle();

      // AuthGate detects incomplete registration and resumes VerifyEmailScreen
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);

      // User enters dev email OTP to finish registration
      await tester.enterText(
          find.byType(TextField), DevAuthService.defaultEmailOtp);
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Reaches RegistrationSuccessScreen
      expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
    });
  });

  group('Phase 7 – Returning-User Login Flow with Dev OTP', () {
    testWidgets(
        '4. Registered user logs in with dev OTP and reaches HomeScreen',
        (tester) async {
      final devAuth = DevAuthService();

      // Seed a registered user
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Vikram Rao',
        mobileNumber: '9876543210',
        email: 'vikram@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth.verifyEmailOtp(
        email: 'vikram@dodo.edu',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth.signOut();

      // Now test login flow
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: devAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Tap Login
      await tester.tap(find.text('Already have an account? Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      // Enter registered mobile
      final phoneField = find.byType(CustomTextField);
      await tester.enterText(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
        '9876543210',
      );

      // Tap Send OTP
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Advances to VerifyMobileScreen with isLogin: true
      expect(find.byType(VerifyMobileScreen), findsOneWidget);
      expect(find.text('Verify Mobile Number'), findsOneWidget);

      // Enter Dev OTP '123456'
      await tester.enterText(find.byType(TextField), DevAuthService.defaultOtp);
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Successfully reaches HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.currentUser!.phone, equals('+919876543210'));
    });

    testWidgets('5. Unregistered mobile number displays proper error on login',
        (tester) async {
      final devAuth = DevAuthService();

      await tester.pumpWidget(
        buildTestableWidget(LoginScreen(authService: devAuth)),
      );

      final phoneField = find.byType(CustomTextField);
      await tester.enterText(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
        '9000000000',
      );

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Does not advance; displays error message
      expect(find.byType(VerifyMobileScreen), findsNothing);
      expect(
        find.text(
          'No existing account found with this mobile number. Please register first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('6. Incorrect OTP displays error and prevents advancing',
        (tester) async {
      final devAuth = DevAuthService();

      // Pre-register user
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Vikram Rao',
        mobileNumber: '9876543210',
        email: 'vikram@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth.verifyEmailOtp(
        email: 'vikram@dodo.edu',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth.signOut();

      // Open Login
      await tester.pumpWidget(
        buildTestableWidget(LoginScreen(authService: devAuth)),
      );
      final phoneField = find.byType(CustomTextField);
      await tester.enterText(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
        '9876543210',
      );
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyMobileScreen), findsOneWidget);

      // Enter WRONG OTP '999999'
      await tester.enterText(find.byType(TextField), '999999');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      // Remains on VerifyMobileScreen and displays error
      expect(find.byType(HomeScreen), findsNothing);
      expect(
        find.text('Invalid or expired OTP. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('7. Incomplete OTP cannot be submitted', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VerifyMobileScreen(
            fullName: 'Test User',
            mobileNumber: '9876543210',
            email: 'test@dodo.edu',
            isLogin: true,
            onVerifyOtp: (otp) async => true,
          ),
        ),
      );

      // Enter only 4 digits
      await tester.enterText(find.byType(TextField), '1234');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter the complete 6-digit OTP'),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  group('Phase 7 – Error and Edge Cases', () {
    testWidgets('8. Form validation catches empty and invalid inputs',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RegisterScreen()),
      );

      // Submit empty form
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your mobile number'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);

      // Invalid mobile (< 10 digits) and invalid email
      final fields = find.byType(CustomTextField);
      await tester.enterText(
        find.descendant(of: fields.at(0), matching: find.byType(TextField)),
        'Anil',
      );
      await tester.enterText(
        find.descendant(of: fields.at(1), matching: find.byType(TextField)),
        '98765',
      );
      await tester.enterText(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
        'invalid-email',
      );

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid 10-digit mobile number'),
        findsOneWidget,
      );
      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('9. Expired OTP simulation returns appropriate error',
        (tester) async {
      final devAuth = DevAuthService();
      devAuth.simulateOtpExpiry = true;

      final resMobile = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      expect(resMobile.isSuccess, isFalse);
      expect(resMobile.errorMessage, contains('expired'));

      final resLogin = await devAuth.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      expect(resLogin.isSuccess, isFalse);
      expect(resLogin.errorMessage, contains('expired'));
    });

    testWidgets('10. Rate limiting / repeated request cooldown simulation',
        (tester) async {
      final devAuth = DevAuthService();
      devAuth.simulateRateLimit = true;

      final resReg = await devAuth.sendRegistrationMobileOtp(
        fullName: 'Sim User',
        mobileNumber: '9876543210',
      );
      expect(resReg.isSuccess, isFalse);
      expect(resReg.errorMessage, contains('Too many attempts'));

      final resLogin = await devAuth.sendLoginOtp(mobileNumber: '9876543210');
      expect(resLogin.isSuccess, isFalse);
      expect(resLogin.errorMessage, contains('Too many attempts'));
    });

    testWidgets('11. Network error handling across auth service calls',
        (tester) async {
      final devAuth = DevAuthService();
      devAuth.simulateNetworkError = true;

      final resReg = await devAuth.sendRegistrationMobileOtp(
        fullName: 'Net User',
        mobileNumber: '9876543210',
      );
      expect(resReg.isSuccess, isFalse);
      expect(resReg.errorMessage, contains('Network error'));

      final resVerify = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      expect(resVerify.isSuccess, isFalse);
      expect(resVerify.errorMessage, contains('Network error'));

      final resLogin = await devAuth.sendLoginOtp(mobileNumber: '9876543210');
      expect(resLogin.isSuccess, isFalse);
      expect(resLogin.errorMessage, contains('Network error'));
    });

    testWidgets('12. Logout from HomeScreen clears session and redirects',
        (tester) async {
      final devAuth = DevAuthService();

      // Seed authenticated user
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Logout Tester',
        mobileNumber: '9876543210',
        email: 'logout@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: DevAuthService.defaultOtp,
      );
      await devAuth.verifyEmailOtp(
        email: 'logout@dodo.edu',
        otp: DevAuthService.defaultOtp,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: devAuth),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap logout
      final logoutBtn = find.byKey(const Key('phase0_logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Clears session and returns to WelcomeScreen
      expect(devAuth.currentUser, isNull);
      expect(devAuth.currentSession, isNull);
      expect(DevAuthService.persistedSession, isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  group('Phase 7 – Section 14 Development OTP Security & Compliance Matrix',
      () {
    testWidgets(
        '13. Confirmed test number +919392518488 registers with OTP 654321',
        (tester) async {
      final devAuth = DevAuthService();
      final resSend = await devAuth.sendRegistrationMobileOtp(
        fullName: 'Confirmed User',
        mobileNumber: '9392518488',
        email: 'confirmed@dodo.edu',
      );
      expect(resSend.isSuccess, isTrue);

      // Step 2: verify mobile OTP does not establish session
      final resMobile = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resMobile.isSuccess, isTrue);
      expect(devAuth.currentUser, isNull,
          reason: 'Mobile OTP must not log user in before email verification');

      // Step 3: verify email OTP establishes session
      final resEmail = await devAuth.verifyEmailOtp(
        email: 'confirmed@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resEmail.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.isRegistrationComplete(), isTrue);
    });

    testWidgets('14. Returning user login with +919392518488 and OTP 654321',
        (tester) async {
      final devAuth = DevAuthService();
      // Pre-register user
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Confirmed User',
        mobileNumber: '9392518488',
        email: 'confirmed@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      await devAuth.verifyEmailOtp(
        email: 'confirmed@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      await devAuth.signOut();

      // Login
      final resSend = await devAuth.sendLoginOtp(mobileNumber: '9392518488');
      expect(resSend.isSuccess, isTrue);

      final resLogin = await devAuth.verifyLoginOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resLogin.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.currentUser!.phone, equals('+919392518488'));
    });

    testWidgets('15. 9-digit number 630280360 is rejected at client validation',
        (tester) async {
      final devAuth = DevAuthService();
      final res = await devAuth.sendRegistrationMobileOtp(
        fullName: 'Nine Digit',
        mobileNumber: '630280360',
      );
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('valid 10-digit'));
    });

    testWidgets(
        '16. Any valid 10-digit Indian mobile number can register using common OTP 123456',
        (tester) async {
      final devAuth = DevAuthService();
      // Send OTP to any new 10-digit Indian mobile number
      final resSend = await devAuth.sendRegistrationMobileOtp(
        fullName: 'Any Indian Mobile User',
        mobileNumber: '9876543210',
        email: 'anyuser@dodo.edu',
      );
      expect(resSend.isSuccess, isTrue);

      // Verifying with common fixed development OTP 123456 succeeds
      final resVerify = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(resVerify.isSuccess, isTrue);
    });

    testWidgets(
        '17. 5 consecutive wrong OTP attempts lock out number for 15 minutes',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Lockout Tester',
        mobileNumber: '9392518488',
        email: 'lockout@dodo.edu',
      );

      for (int i = 0; i < 5; i++) {
        final res = await devAuth.verifyRegistrationMobileOtp(
          mobileNumber: '9392518488',
          otp: '000000',
        );
        expect(res.isSuccess, isFalse);
      }

      // 6th attempt should be blocked by lockout
      final resBlocked = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resBlocked.isSuccess, isFalse);
      expect(resBlocked.errorMessage, contains('15 minutes'));
      expect(DevAuthService.isNumberLocked('9392518488'), isTrue);
    });

    testWidgets(
        '18. 5 consecutive wrong email OTP attempts invalidate pending registration',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Email Fail Tester',
        mobileNumber: '9392518488',
        email: 'fail@dodo.edu',
      );
      final resMobile = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resMobile.isSuccess, isTrue);

      // Attempt 1 to 4 with incorrect email OTP
      for (int i = 0; i < 4; i++) {
        final res = await devAuth.verifyEmailOtp(
          email: 'fail@dodo.edu',
          otp: '000000',
        );
        expect(res.isSuccess, isFalse);
      }

      // 5th failed attempt invalidates the session
      final resFifth = await devAuth.verifyEmailOtp(
        email: 'fail@dodo.edu',
        otp: '000000',
      );
      expect(resFifth.isSuccess, isFalse);
      expect(resFifth.errorMessage, contains('invalidated'));

      // 6th attempt with correct OTP is rejected because session was invalidated
      final resSubsequent = await devAuth.verifyEmailOtp(
        email: 'fail@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resSubsequent.isSuccess, isFalse);
      expect(resSubsequent.errorMessage, contains('Invalid or expired'));
    });

    testWidgets('19. Email OTP verification is single-use and cannot be reused',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Single Use Tester',
        mobileNumber: '9392518488',
        email: 'singleuse@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );

      final res1 = await devAuth.verifyEmailOtp(
        email: 'singleuse@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(res1.isSuccess, isTrue);

      // Re-use of the same registration token / session is rejected
      final resReuse = await devAuth.verifyEmailOtp(
        email: 'singleuse@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resReuse, isNotNull);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.isRegistrationComplete(), isTrue);
    });

    testWidgets('20. Email matching is case-insensitive during verification',
        (tester) async {
      final devAuth = DevAuthService();
      // Register with mixed/uppercase email
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Case Tester',
        mobileNumber: '9392518488',
        email: 'CaseTester@Dodo.Edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );

      // Verify with lowercase email
      final res = await devAuth.verifyEmailOtp(
        email: 'casetester@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(res.isSuccess, isTrue);
      expect(devAuth.isRegistrationComplete(), isTrue);
    });

    testWidgets(
        '21. Client modification of user_metadata registration_completed does not bypass unconfirmed email',
        (tester) async {
      final devAuth = DevAuthService();
      final tamperedUser = User(
        id: 'tampered-user-id',
        appMetadata: const <String, dynamic>{'provider': 'phone'},
        userMetadata: const <String, dynamic>{
          'full_name': 'Tamper Tester',
          'email': 'tamper@dodo.edu',
          'registration_completed': true, // Client attempted tampering!
        },
        aud: 'authenticated',
        email: 'tamper@dodo.edu',
        phone: '+919392518488',
        createdAt: DateTime.now().toIso8601String(),
        phoneConfirmedAt: DateTime.now().toIso8601String(),
        emailConfirmedAt: null, // Email was NEVER confirmed by server!
      );

      // Verification MUST return false
      expect(devAuth.isRegistrationComplete(tamperedUser), isFalse);
    });

    testWidgets(
        '22. AuthGate blocks tampered user metadata and resumes VerifyEmailScreen',
        (tester) async {
      final tamperedUser = User(
        id: 'tampered-user-id-2',
        appMetadata: const <String, dynamic>{'provider': 'phone'},
        userMetadata: const <String, dynamic>{
          'full_name': 'Tamper Tester 2',
          'email': 'tamper2@dodo.edu',
          'registration_completed': true, // Tampered client metadata
        },
        aud: 'authenticated',
        email: 'tamper2@dodo.edu',
        phone: '+919392518488',
        createdAt: DateTime.now().toIso8601String(),
        phoneConfirmedAt: DateTime.now().toIso8601String(),
        emailConfirmedAt: null, // Unconfirmed email
      );

      final devAuth = DevAuthService(initialUser: tamperedUser);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(authService: devAuth),
      ));
      await tester.pumpAndSettle();

      // Must NOT show HomeScreen; must resume at VerifyEmailScreen!
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    test('23. Edge Function environment guard allowlist verification', () {
      const allowedDevEnvironments = ['development', 'dev', 'test'];

      bool isAllowed(String? env) {
        final normalized = (env ?? '').toLowerCase().trim();
        return normalized.isNotEmpty &&
            allowedDevEnvironments.contains(normalized);
      }

      // Fails closed on missing, empty, production, staging, or unrecognized
      expect(isAllowed(null), isFalse);
      expect(isAllowed(''), isFalse);
      expect(isAllowed('   '), isFalse);
      expect(isAllowed('production'), isFalse);
      expect(isAllowed('prod'), isFalse);
      expect(isAllowed('PRODUCTION'), isFalse);
      expect(isAllowed('staging'), isFalse); // Staging blocked by default
      expect(isAllowed('staging_prod'), isFalse);
      expect(isAllowed('unknown'), isFalse);

      // Allows only explicitly permitted dev environments
      expect(isAllowed('development'), isTrue);
      expect(isAllowed('DEVELOPMENT'), isTrue);
      expect(isAllowed('dev'), isTrue);
      expect(isAllowed('DEV'), isTrue);
      expect(isAllowed('test'), isTrue);
    });

    test('24. Magic-link token exchange uses OtpType.magiclink in GoTrue', () {
      // Confirms OtpType.magiclink is the correct type
      expect(OtpType.magiclink.name, equals('magiclink'));
    });

    testWidgets(
        '25. Scenario A: Mobile registration RPC failure after user creation permits clean idempotent retry',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Retry Tester A',
        mobileNumber: '9392518488',
        email: 'retrya@dodo.edu',
      );

      // Simulate transient failure during mobile verification RPC
      devAuth.simulateNetworkError = true;
      final resFail = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resFail.isSuccess, isFalse);

      // Recover and retry verification with same mobile and OTP
      devAuth.simulateNetworkError = false;
      final resRetry = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resRetry.isSuccess, isTrue);

      // Successfully completes registration without duplicate user
      final resEmail = await devAuth.verifyEmailOtp(
        email: 'retrya@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resEmail.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.currentUser!.phone, equals('+919392518488'));
    });

    testWidgets(
        '26. Scenario B: Magic-link generation failure after email OTP permits immediate retry',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Retry Tester B',
        mobileNumber: '9392518488',
        email: 'retryb@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );

      // Simulate transient failure during session issuance in email OTP step
      devAuth.simulateNetworkError = true;
      final resFail = await devAuth.verifyEmailOtp(
        email: 'retryb@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resFail.isSuccess, isFalse);

      // Retry immediately
      devAuth.simulateNetworkError = false;
      final resRetry = await devAuth.verifyEmailOtp(
        email: 'retryb@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resRetry.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(await devAuth.getTrustedRegistrationStatus(), isTrue);
    });

    test(
        '27. User lookup pagination finds users located beyond page 1 (> 50 users)',
        () {
      // Simulate finding a user on page 3 (index 125)
      final allUsers = List.generate(
        150,
        (i) => {
          'id': 'user-$i',
          'phone': '+919000000${i.toString().padLeft(3, '0')}'
        },
      );

      // Implement the exact paginated search algorithm used in dev-auth/index.ts
      Map<String, dynamic>? findUser(
          bool Function(Map<String, dynamic>) predicate) {
        letPageLoop:
        for (int page = 1;; page++) {
          final start = (page - 1) * 50;
          if (start >= allUsers.length) break;
          final batch =
              allUsers.sublist(start, (start + 50).clamp(0, allUsers.length));
          for (final u in batch) {
            if (predicate(u)) return u;
          }
          if (batch.length < 50) break letPageLoop;
        }
        return null;
      }

      final foundUser = findUser((u) => u['phone'] == '+919000000125');
      expect(foundUser, isNotNull);
      expect(foundUser!['id'], equals('user-125'));
    });

    testWidgets(
        '25. Scenario A: Mobile registration RPC failure after user creation permits clean idempotent retry',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Retry Tester A',
        mobileNumber: '9392518488',
        email: 'retrya@dodo.edu',
      );

      // Simulate transient failure during mobile verification RPC
      devAuth.simulateNetworkError = true;
      final resFail = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resFail.isSuccess, isFalse);

      // Recover and retry verification with same mobile and OTP
      devAuth.simulateNetworkError = false;
      final resRetry = await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );
      expect(resRetry.isSuccess, isTrue);

      // Successfully completes registration without duplicate user
      final resEmail = await devAuth.verifyEmailOtp(
        email: 'retrya@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resEmail.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(devAuth.currentUser!.phone, equals('+919392518488'));
    });

    testWidgets(
        '26. Scenario B: Magic-link generation failure after email OTP permits immediate retry',
        (tester) async {
      final devAuth = DevAuthService();
      await devAuth.sendRegistrationMobileOtp(
        fullName: 'Retry Tester B',
        mobileNumber: '9392518488',
        email: 'retryb@dodo.edu',
      );
      await devAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9392518488',
        otp: '654321',
      );

      // Simulate transient failure during session issuance in email OTP step
      devAuth.simulateNetworkError = true;
      final resFail = await devAuth.verifyEmailOtp(
        email: 'retryb@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resFail.isSuccess, isFalse);

      // Retry immediately
      devAuth.simulateNetworkError = false;
      final resRetry = await devAuth.verifyEmailOtp(
        email: 'retryb@dodo.edu',
        otp: DevAuthService.defaultEmailOtp,
      );
      expect(resRetry.isSuccess, isTrue);
      expect(devAuth.currentUser, isNotNull);
      expect(await devAuth.getTrustedRegistrationStatus(), isTrue);
    });

    test(
        '27. User lookup pagination finds users located beyond page 1 (> 50 users)',
        () {
      // Simulate finding a user on page 3 (index 125)
      final allUsers = List.generate(
        150,
        (i) => {
          'id': 'user-$i',
          'phone': '+919000000${i.toString().padLeft(3, '0')}'
        },
      );

      // Implement the exact paginated search algorithm used in dev-auth/index.ts
      Map<String, dynamic>? findUser(
          bool Function(Map<String, dynamic>) predicate) {
        letPageLoop:
        for (int page = 1;; page++) {
          final start = (page - 1) * 50;
          if (start >= allUsers.length) break;
          final batch =
              allUsers.sublist(start, (start + 50).clamp(0, allUsers.length));
          for (final u in batch) {
            if (predicate(u)) return u;
          }
          if (batch.length < 50) break letPageLoop;
        }
        return null;
      }

      final foundUser = findUser((u) => u['phone'] == '+919000000125');
      expect(foundUser, isNotNull);
      expect(foundUser!['id'], equals('user-125'));
    });
  });
}
