import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cooldown_timer.dart';
import '../../core/widgets/otp_input_field.dart';
import '../../core/widgets/primary_button.dart';
import '../home_screen.dart';
import 'verify_email_screen.dart';

/// Screen 3: Mobile OTP verification screen.
class VerifyMobileScreen extends StatefulWidget {
  final String fullName;
  final String mobileNumber;
  final String email;
  final bool isLogin;
  final IAuthService? authService;

  /// Callback to execute in Phase 5 when the user taps Verify.
  /// Must return true if verification succeeded to permit advancing.
  final Future<bool> Function(String otp)? onVerifyOtp;

  /// Callback to execute in Phase 5 when resend is triggered.
  final Future<void> Function()? onResendOtp;

  const VerifyMobileScreen({
    super.key,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
    this.isLogin = false,
    this.authService,
    this.onVerifyOtp,
    this.onResendOtp,
  });

  @override
  State<VerifyMobileScreen> createState() => _VerifyMobileScreenState();
}

class _VerifyMobileScreenState extends State<VerifyMobileScreen> {
  late final TextEditingController _otpController;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _formatMobile(String number) {
    if (number.length == 10) {
      return '+91 ${number.substring(0, 5)} ${number.substring(5)}';
    }
    return '+91 $number';
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
        if (widget.isLogin) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(authService: widget.authService),
            ),
            (route) => false,
          );
        } else {
          final auth = widget.authService ?? AuthService.instance;
          // Step 4: Attach email to the authenticated user
          await auth.attachEmail(email: widget.email);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyEmailScreen(
                  fullName: widget.fullName,
                  mobileNumber: widget.mobileNumber,
                  email: widget.email,
                  authService: auth,
                  onVerifyOtp: (emailOtp) async {
                    final res = await auth.verifyEmailOtp(
                      email: widget.email,
                      otp: emailOtp,
                    );
                    return res.isSuccess;
                  },
                ),
              ),
            );
          }
        }
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
        title: const Text('Verify Mobile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
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
                        child: Text(
                          widget.isLogin ? 'Login' : 'Step 2 of 3',
                          style: const TextStyle(
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
                    'Verify Mobile Number',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Display mobile number + edit button
                  Row(
                    children: [
                      Text(
                        'Code sent to ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _formatMobile(widget.mobileNumber),
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
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Edit mobile number',
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
                    text: 'Verify Mobile',
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
                          if (widget.isLogin) {
                            await auth.sendLoginOtp(
                              mobileNumber: widget.mobileNumber,
                            );
                          } else {
                            await auth.sendRegistrationMobileOtp(
                              fullName: widget.fullName,
                              mobileNumber: widget.mobileNumber,
                            );
                          }
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
