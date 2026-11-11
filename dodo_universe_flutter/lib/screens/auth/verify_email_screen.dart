import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cooldown_timer.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/otp_input_field.dart';
import '../../core/widgets/primary_button.dart';
import 'registration_success_screen.dart';

/// Screen 4: Email OTP verification screen.
class VerifyEmailScreen extends StatefulWidget {
  final String fullName;
  final String mobileNumber;
  final String email;
  final IAuthService? authService;

  /// Callback to execute in Phase 5 when the user taps Verify.
  /// Must return true if verification succeeded to permit advancing.
  final Future<bool> Function(String otp)? onVerifyOtp;

  /// Callback to execute in Phase 5 when resend is triggered.
  final Future<void> Function()? onResendOtp;

  /// Callback to execute in Phase 5 when email is changed.
  final Future<void> Function(String newEmail)? onEmailChanged;

  const VerifyEmailScreen({
    super.key,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
    this.authService,
    this.onVerifyOtp,
    this.onResendOtp,
    this.onEmailChanged,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final TextEditingController _otpController;
  late String _currentEmail;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _currentEmail = widget.email;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showEditEmailDialog() {
    final emailController = TextEditingController(text: _currentEmail);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: const Text('Edit Email Address'),
          content: Form(
            key: formKey,
            child: CustomTextField(
              label: 'New Email',
              hintText: 'Enter new email address',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an email';
                }
                final emailRegex = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                );
                if (!emailRegex.hasMatch(val.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newEmail = emailController.text.trim();
                  setState(() {
                    _currentEmail = newEmail;
                    _errorMessage = null;
                  });
                  _otpController.clear();
                  Navigator.pop(dialogContext);
                  widget.onEmailChanged?.call(newEmail);
                  if (widget.onEmailChanged == null) {
                    final auth = widget.authService ?? AuthService.instance;
                    auth.attachEmail(email: newEmail);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit OTP';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    if (widget.onVerifyOtp == null) {
      setState(() {
        _errorMessage = 'Verification service is not connected yet.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    try {
      final isVerified = await widget.onVerifyOtp!(otp);
      if (isVerified && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationSuccessScreen(
              fullName: widget.fullName,
              mobileNumber: widget.mobileNumber,
              email: _currentEmail,
              authService: widget.authService,
            ),
          ),
          (route) => route.isFirst,
        );
      } else if (!isVerified && mounted) {
        setState(() {
          _errorMessage = 'Invalid or expired OTP. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Verify Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.authService?.signOut();
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreenLight,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Text(
                          'Step 3 of 3',
                          style: TextStyle(
                            color: AppTheme.primaryGreenDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Verify Email Address',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Display email address + edit button
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Code sent to ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _currentEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppTheme.primaryGreen,
                        ),
                        onPressed: _showEditEmailDialog,
                        tooltip: 'Edit email address',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 6-Digit OTP Field
                  OtpInputField(
                    controller: _otpController,
                    hasError: _errorMessage != null,
                    onChanged: (val) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                    onCompleted: (val) => _handleVerify(),
                  ),

                  // Error Message Display
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Verify Button
                  PrimaryButton(
                    text: 'Verify Email',
                    isLoading: _isVerifying,
                    onPressed: _handleVerify,
                  ),
                  const SizedBox(height: 24),

                  // Cooldown Resend Timer
                  CooldownTimer(
                    cooldownSeconds: 60,
                    onResend: widget.onResendOtp ??
                        () async {
                          final auth =
                              widget.authService ?? AuthService.instance;
                          await auth.attachEmail(email: _currentEmail);
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
