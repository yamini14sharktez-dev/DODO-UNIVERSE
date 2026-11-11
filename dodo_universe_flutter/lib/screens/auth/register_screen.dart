import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import 'verify_mobile_screen.dart';

/// Screen 2: Registration details collection form (Name, Mobile, Email).
class RegisterScreen extends StatefulWidget {
  final IAuthService? authService;
  final void Function(String fullName, String mobileNumber, String email)?
      onRegistrationValidated;

  const RegisterScreen({
    super.key,
    this.authService,
    this.onRegistrationValidated,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  late final FocusNode _phoneFocus;
  late final FocusNode _emailFocus;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();

    _phoneFocus = FocusNode();
    _emailFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile number';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fullName = _nameController.text.trim();
    final mobileNumber = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (widget.onRegistrationValidated != null) {
      widget.onRegistrationValidated!(fullName, mobileNumber, email);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = widget.authService ?? AuthService.instance;
      final result = await auth.sendRegistrationMobileOtp(
        fullName: fullName,
        mobileNumber: mobileNumber,
        email: email,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyMobileScreen(
              fullName: fullName,
              mobileNumber: mobileNumber,
              email: email,
              authService: auth,
              onVerifyOtp: (otp) async {
                final res = await auth.verifyRegistrationMobileOtp(
                  mobileNumber: mobileNumber,
                  otp: otp,
                );
                return res.isSuccess;
              },
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              result.errorMessage ?? 'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        title: const Text('Create Account'),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Indicator / Header
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
                            'Step 1 of 3',
                            style: TextStyle(
                              color: AppTheme.primaryGreenDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to DODO',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your details to create your university account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full Name
                    CustomTextField(
                      label: 'Full Name',
                      hintText: 'e.g. Rahul Sharma',
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      validator: _validateName,
                      onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),

                    // Mobile Number
                    CustomTextField(
                      label: 'Mobile Number',
                      hintText: '10-digit number',
                      controller: _phoneController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        width: 60,
                        child: const Text(
                          '+91',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: _validatePhone,
                      onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),

                    // Email Address
                    CustomTextField(
                      label: 'Email Address',
                      hintText: 'e.g. rahul@example.com',
                      controller: _emailController,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _handleContinue(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 24),

                    // Continue Button
                    PrimaryButton(
                      text: 'Continue',
                      isLoading: _isLoading,
                      onPressed: _handleContinue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
