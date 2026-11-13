import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dodo_universe/core/theme/app_theme.dart';
import 'package:dodo_universe/core/widgets/custom_text_field.dart';
import 'package:dodo_universe/core/widgets/primary_button.dart';
import 'package:dodo_universe/screens/auth/welcome_screen.dart';
import 'package:dodo_universe/screens/auth/register_screen.dart';
import 'package:dodo_universe/screens/auth/verify_mobile_screen.dart';
import 'package:dodo_universe/screens/auth/verify_email_screen.dart';
import 'package:dodo_universe/screens/auth/registration_success_screen.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  group('WelcomeScreen', () {
    testWidgets('renders branding and navigation buttons', (tester) async {
      bool createAccountTapped = false;
      bool loginTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          WelcomeScreen(
            onCreateAccountTap: () => createAccountTapped = true,
            onLoginTap: () => loginTapped = true,
          ),
        ),
      );

      expect(find.text('DODO Universe'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);

      await tester.tap(find.text('Create Account'));
      expect(createAccountTapped, isTrue);

      await tester.tap(find.text('Already have an account? Login'));
      expect(loginTapped, isTrue);
    });
  });

  group('RegisterScreen', () {
    testWidgets('validates required fields and rejects invalid data',
        (tester) async {
      bool validated = false;

      await tester.pumpWidget(
        buildTestableWidget(
          RegisterScreen(
            onRegistrationValidated: (name, phone, email) => validated = true,
          ),
        ),
      );

      // Attempt submit without filling fields
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your mobile number'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(validated, isFalse);

      // Enter invalid phone (< 10 digits) and invalid email
      final fields = find.byType(CustomTextField);
      await tester.enterText(
        find.descendant(of: fields.at(0), matching: find.byType(TextField)),
        'Rahul',
      );
      await tester.enterText(
        find.descendant(of: fields.at(1), matching: find.byType(TextField)),
        '12345',
      );
      await tester.enterText(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
        'notanemail',
      );

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid 10-digit mobile number'),
        findsOneWidget,
      );
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(validated, isFalse);

      // Fix phone and email
      await tester.enterText(
        find.descendant(of: fields.at(1), matching: find.byType(TextField)),
        '9876543210',
      );
      await tester.enterText(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
        'rahul@example.com',
      );

      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(validated, isTrue);
    });
  });

  group('VerifyMobileScreen - Unverified Isolation & Navigation Rules', () {
    testWidgets(
        'mobile verification without a callback does not advance and shows service message',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const VerifyMobileScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: null, // No callback provided
          ),
        ),
      );

      // Enter complete 6 digits
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      // Confirms navigation DID NOT advance to VerifyEmailScreen
      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(find.text('Verify Mobile Number'), findsOneWidget);
      expect(
        find.text('Verification service is not connected yet.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'failed mobile verification (callback returns false) does not advance',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VerifyMobileScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: (otp) async => false, // Fails verification
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(
        find.text('Invalid or expired OTP. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'successful mobile callback permits advance to VerifyEmailScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VerifyMobileScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: (otp) async => true, // Successful verification
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      // Confirms navigation advanced to VerifyEmailScreen
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });
  });

  group('VerifyEmailScreen - Unverified Isolation & Navigation Rules', () {
    testWidgets(
        'email verification without a callback does not advance and shows service message',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const VerifyEmailScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: null, // No callback provided
          ),
        ),
      );

      // Enter complete 6 digits
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      // Confirms navigation DID NOT advance to RegistrationSuccessScreen
      expect(find.byType(RegistrationSuccessScreen), findsNothing);
      expect(find.text('Verify Email Address'), findsOneWidget);
      expect(
        find.text('Verification service is not connected yet.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'failed email verification (callback returns false) does not advance',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VerifyEmailScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: (otp) async => false, // Fails verification
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationSuccessScreen), findsNothing);
      expect(
        find.text('Invalid or expired OTP. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'successful email callback permits advance to RegistrationSuccessScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VerifyEmailScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onVerifyOtp: (otp) async => true, // Successful verification
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      // Confirms navigation advanced to RegistrationSuccessScreen
      expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
    });

    testWidgets('allows editing email address in dialog', (tester) async {
      String updatedEmail = '';

      await tester.pumpWidget(
        buildTestableWidget(
          VerifyEmailScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'initial@example.com',
            onEmailChanged: (newEmail) async => updatedEmail = newEmail,
          ),
        ),
      );

      expect(find.text('Verify Email Address'), findsOneWidget);
      expect(find.text('initial@example.com'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Email Address'), findsOneWidget);

      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogField, 'updated@example.com');
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('updated@example.com'), findsOneWidget);
      expect(updatedEmail, equals('updated@example.com'));
    });
  });

  group('RegistrationSuccessScreen', () {
    testWidgets('renders success details and continue CTA', (tester) async {
      bool continueTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          RegistrationSuccessScreen(
            fullName: 'Rahul Sharma',
            mobileNumber: '9876543210',
            email: 'rahul@example.com',
            onContinue: () => continueTapped = true,
          ),
        ),
      );

      expect(find.text('Registration Successful'), findsOneWidget);
      expect(find.textContaining('Rahul Sharma'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('rahul@example.com'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue to Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Login'));
      expect(continueTapped, isTrue);
    });
  });
}
