import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dodo_universe/core/theme/app_theme.dart';
import 'package:dodo_universe/core/widgets/custom_text_field.dart';
import 'package:dodo_universe/core/widgets/primary_button.dart';
import 'package:dodo_universe/core/widgets/otp_input_field.dart';
import 'package:dodo_universe/core/widgets/cooldown_timer.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  group('CustomTextField', () {
    testWidgets('renders label and hintText correctly', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          CustomTextField(
            label: 'Mobile Number',
            hintText: 'Enter 10-digit number',
            controller: controller,
          ),
        ),
      );

      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Enter 10-digit number'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9876543210');
      expect(controller.text, equals('9876543210'));
    });
  });

  group('PrimaryButton', () {
    testWidgets('renders text and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          PrimaryButton(
            text: 'Continue',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows CircularProgressIndicator when loading and ignores tap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          PrimaryButton(
            text: 'Continue',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, isFalse);
    });
  });

  group('OtpInputField', () {
    testWidgets('renders 6 digit boxes and fires onCompleted', (tester) async {
      String completedCode = '';
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          OtpInputField(
            controller: controller,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      );

      // Verify 6 digit containers exist
      expect(find.byType(Container), findsWidgets);

      // Enter 6 digits into the underlying text field
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(completedCode, equals('123456'));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });
  });

  group('CooldownTimer', () {
    testWidgets('displays prefix and countdown label', (tester) async {
      bool resendCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          CooldownTimer(
            cooldownSeconds: 30,
            onResend: () => resendCalled = true,
          ),
        ),
      );

      expect(find.text("Didn't receive the code? "), findsOneWidget);
      expect(find.textContaining('Resend OTP in'), findsOneWidget);

      // Fast forward past cooldown
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Resend OTP'), findsOneWidget);
      await tester.tap(find.text('Resend OTP'));
      expect(resendCalled, isTrue);
    });
  });
}
