import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/go_auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../home_screen.dart';
import 'verify_email_screen.dart';
import 'welcome_screen.dart';

/// App authentication gate: Root entry point for DODO Universe.
///
/// Determines authentication and registration completion state:
/// 1. Shows a loading indicator while determining authentication state.
/// 2. If unauthenticated -> [WelcomeScreen].
/// 3. If authenticated and registration complete -> [Phase0Screen].
/// 4. If authenticated but registration incomplete -> resumes [VerifyEmailScreen].
/// 5. Dynamically reacts to session changes, expiration, and logouts.
class AuthGate extends StatefulWidget {
  final IAuthService? authService;
  final bool initialLoading;

  const AuthGate({
    super.key,
    this.authService,
    this.initialLoading = false,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final IAuthService _auth;
  StreamSubscription<AuthState>? _authSubscription;
  late bool _isLoading;
  User? _currentUser;
  bool _isTrustedComplete = false;
  bool _hasProfileQueryFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ??
        (AppConfig.current().useGoBackend
            ? GoAuthService.create()
            : AuthService.instance);
    _isLoading = widget.initialLoading || _auth.currentUser != null;
    _currentUser = _auth.currentUser;
    _initAuth();
  }

  Future<void> _verifyTrustedCompletion() async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isTrustedComplete = false;
        _hasProfileQueryFailed = false;
        _isLoading = false;
      });
      return;
    }

    try {
      final isComplete = await _auth.getTrustedRegistrationStatus(user);
      if (!mounted) return;
      setState(() {
        _isTrustedComplete = isComplete;
        _hasProfileQueryFailed = false;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTrustedComplete = false;
        _hasProfileQueryFailed = true;
        _errorMessage =
            'Unable to verify registration profile. Please check your network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _initAuth() async {
    // Only attempt real Supabase initialization if a custom auth service is not provided and not using Go backend
    if (widget.authService == null &&
        !AppConfig.current().useGoBackend &&
        !SupabaseManager.isInitialized) {
      setState(() {
        _isLoading = true;
      });
      await SupabaseManager.initialize();
      if (!mounted) return;
      _currentUser = _auth.currentUser;
    }

    _authSubscription = _auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _currentUser = null;
          _isTrustedComplete = false;
          _hasProfileQueryFailed = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentUser = data.session?.user ?? _auth.currentUser;
          _isLoading = true;
        });
        _verifyTrustedCompletion();
      }
    });

    await _verifyTrustedCompletion();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            key: Key('auth_gate_loading_indicator'),
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    if (_hasProfileQueryFailed) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unable to verify profile. Please retry.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('auth_gate_retry_button'),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _verifyTrustedCompletion();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _currentUser;
    if (user == null) {
      return WelcomeScreen(authService: _auth);
    }

    if (_isTrustedComplete) {
      return HomeScreen(authService: _auth);
    }

    // Incomplete registration: resume email verification
    final fullName = (user.userMetadata?['full_name'] as String?) ?? '';
    final mobileNumber = user.phone ?? '';
    final email = user.newEmail ??
        user.email ??
        (user.userMetadata?['email'] as String?) ??
        '';

    return VerifyEmailScreen(
      fullName: fullName,
      mobileNumber: mobileNumber,
      email: email,
      authService: _auth,
      onVerifyOtp: (otp) async {
        final targetEmail = email.isNotEmpty
            ? email
            : (user.email ?? (user.userMetadata?['email'] as String?) ?? '');
        final res = await _auth.verifyEmailOtp(email: targetEmail, otp: otp);
        if (res.isSuccess) {
          if (mounted) {
            setState(() {
              _currentUser = _auth.currentUser;
              _isLoading = true;
            });
            await _verifyTrustedCompletion();
          }
          return true;
        }
        return false;
      },
      onEmailChanged: (newEmail) async {
        await _auth.attachEmail(email: newEmail);
      },
      onResendOtp: () async {
        await _auth.attachEmail(email: email);
      },
    );
  }
}
