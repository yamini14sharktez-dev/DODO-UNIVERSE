import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../supabase/supabase_client.dart';

/// Represents the result of an authentication operation.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  final Session? session;

  const AuthResult.success({this.user, this.session})
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null,
        session = null;

  @override
  String toString() => isSuccess
      ? 'AuthResult.success(user: ${user?.id})'
      : 'AuthResult.failure($errorMessage)';
}

/// Abstract contract for DODO Universe native authentication.
abstract class IAuthService {
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  });

  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  });

  Future<AuthResult> attachEmail({required String email});

  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  });

  Future<AuthResult> sendLoginOtp({required String mobileNumber});

  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  });

  Future<void> signOut();

  User? get currentUser;
  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;

  /// Authoritative registration completion check against the trusted backend/database.
  Future<bool> getTrustedRegistrationStatus([User? user]);

  bool isRegistrationComplete([User? user]);
}

/// Production implementation of native Supabase authentication with development
/// OTP Edge Function support.
class AuthService implements IAuthService {
  final SupabaseClient? _customClient;
  final bool? _customDevMode;
  String? _pendingRegistrationToken;
  String? _pendingRegistrationEmail;
  String? _pendingRegistrationFullName;

  AuthService({SupabaseClient? client, bool? isDevMode})
      : _customClient = client,
        _customDevMode = isDevMode;

  static IAuthService instance = AuthService();

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    if (SupabaseManager.isInitialized) return SupabaseManager.client;
    return null;
  }

  bool get _isDevMode =>
      _customDevMode ??
      (AppConfig.current().environment != AppEnvironment.production);

  /// Formats an Indian 10-digit mobile number into E.164 (+91XXXXXXXXXX) format.
  static String formatIndianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return phone.startsWith('+') ? phone : '+$digits';
  }

  @override
  User? get currentUser => _client?.auth.currentUser;

  @override
  Session? get currentSession => _client?.auth.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async {
    final targetUser = user ?? currentUser;
    if (targetUser == null) return false;

    final client = _client;
    if (client == null) {
      return isRegistrationComplete(targetUser);
    }

    try {
      final res = await client
          .from('profiles')
          .select('is_registration_complete')
          .eq('id', targetUser.id)
          .maybeSingle();

      if (res == null) {
        // Missing profile record
        return false;
      }

      return res['is_registration_complete'] == true;
    } on SocketException {
      rethrow;
    } catch (e) {
      debugPrint('AuthService.getTrustedRegistrationStatus error: $e');
      rethrow;
    }
  }

  @override
  bool isRegistrationComplete([User? user]) {
    final targetUser = user ?? currentUser;
    if (targetUser == null) return false;

    // Both phone and email MUST have server-confirmed timestamps.
    // Client-editable user_metadata is NOT trusted on its own.
    final hasConfirmedPhone = targetUser.phoneConfirmedAt != null ||
        (targetUser.phone != null && targetUser.phone!.isNotEmpty);
    final hasEmail = targetUser.email != null && targetUser.email!.isNotEmpty;
    final hasConfirmedEmail = targetUser.emailConfirmedAt != null;

    return hasConfirmedPhone && hasEmail && hasConfirmedEmail;
  }

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized. Please verify configuration.',
      );
    }

    try {
      final formattedPhone = formatIndianPhone(mobileNumber);

      // Save email and full name for the registration verification sequence
      _pendingRegistrationEmail = email?.trim();
      _pendingRegistrationFullName = fullName.trim();

      // In non-production, development OTP Edge Function is the exclusive handler
      if (_isDevMode) {
        try {
          final res = await client.functions.invoke(
            'dev-auth',
            body: {
              'action': 'send-mobile-otp',
              'mobile_number': formattedPhone,
              'is_login': false,
            },
          );
          if (res.status == 200) {
            return const AuthResult.success();
          } else if (res.data is Map && res.data['error'] != null) {
            return AuthResult.failure(res.data['error'].toString());
          }
          return const AuthResult.failure(
            'Development OTP service returned an unexpected response.',
          );
        } on FunctionException catch (e) {
          final details = e.details;
          final serverError = details is Map && details['error'] != null
              ? details['error'].toString()
              : (e.status == 0
                  ? 'Network connection error contacting development auth service.'
                  : (e.reasonPhrase ?? 'status ${e.status}'));
          final errorMsg = e.status == 404
              ? 'Development authentication endpoint not available (404): $serverError. Ensure ENVIRONMENT=development is configured.'
              : (e.status == 0
                  ? 'Development auth service error: Network connection error.'
                  : serverError);
          return AuthResult.failure(errorMsg);
        } catch (e) {
          return AuthResult.failure('Development auth service error: $e');
        }
      }

      final metadata = <String, dynamic>{
        'full_name': fullName.trim(),
      };
      if (email != null && email.trim().isNotEmpty) {
        metadata['email'] = email.trim();
      }

      await client.auth.signInWithOtp(
        phone: formattedPhone,
        data: metadata,
        shouldCreateUser: true,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to send mobile OTP: $e');
    }
  }

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized.',
      );
    }

    try {
      final formattedPhone = formatIndianPhone(mobileNumber);

      // In non-production, development OTP Edge Function is the exclusive handler
      if (_isDevMode) {
        try {
          final res = await client.functions.invoke(
            'dev-auth',
            body: {
              'action': 'verify-mobile-otp',
              'mobile_number': formattedPhone,
              'otp': otp.trim(),
              if (_pendingRegistrationEmail != null &&
                  _pendingRegistrationEmail!.isNotEmpty)
                'email': _pendingRegistrationEmail,
              if (_pendingRegistrationFullName != null &&
                  _pendingRegistrationFullName!.isNotEmpty)
                'full_name': _pendingRegistrationFullName,
            },
          );
          if (res.status == 200 &&
              res.data is Map &&
              res.data['success'] == true) {
            _pendingRegistrationToken =
                res.data['registration_token']?.toString();
            // Step 2 does NOT establish an authenticated session.
            // Proceed to Step 3 (Email verification).
            return const AuthResult.success();
          } else if (res.data is Map && res.data['error'] != null) {
            return AuthResult.failure(res.data['error'].toString());
          }
          return const AuthResult.failure(
            'Development OTP verification failed.',
          );
        } on FunctionException catch (e) {
          final details = e.details;
          final serverError = details is Map && details['error'] != null
              ? details['error'].toString()
              : (e.status == 0
                  ? 'Network connection error contacting development auth service.'
                  : (e.reasonPhrase ?? 'status ${e.status}'));
          final errorMsg = e.status == 404
              ? 'Development authentication endpoint not available (404): $serverError. Ensure ENVIRONMENT=development is configured.'
              : (e.status == 0
                  ? 'Development auth service error: Network connection error.'
                  : serverError);
          return AuthResult.failure(errorMsg);
        } catch (e) {
          return AuthResult.failure('Development auth service error: $e');
        }
      }

      final response = await client.auth.verifyOTP(
        phone: formattedPhone,
        token: otp.trim(),
        type: OtpType.sms,
      );

      if (response.user != null || response.session != null) {
        return AuthResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthResult.failure(
        'Mobile OTP verification did not return an authenticated session.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to verify mobile OTP: $e');
    }
  }

  @override
  Future<AuthResult> attachEmail({required String email}) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized.',
      );
    }

    try {
      // In dev mode with pending registration, email attachment is handled in Step 3/4
      if (_isDevMode && _pendingRegistrationToken != null) {
        _pendingRegistrationEmail = email.trim();
        return const AuthResult.success();
      }

      final response = await client.auth.updateUser(
        UserAttributes(email: email.trim()),
      );
      return AuthResult.success(user: response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to attach email address: $e');
    }
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized.',
      );
    }

    try {
      // In non-production with pending registration token, exchange via dev-auth
      if (_isDevMode && _pendingRegistrationToken != null) {
        try {
          final res = await client.functions.invoke(
            'dev-auth',
            body: {
              'action': 'verify-email-otp',
              'email': email.trim(),
              'otp': otp.trim(),
              'registration_token': _pendingRegistrationToken,
            },
          );
          if (res.status == 200 &&
              res.data is Map &&
              res.data['token_hash'] != null) {
            final tokenHash = res.data['token_hash'].toString();
            // Step 4: Establish genuine GoTrue session with verified email and phone
            final authResponse = await client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.magiclink,
            );
            _pendingRegistrationToken = null;
            _pendingRegistrationEmail = null;
            _pendingRegistrationFullName = null;
            return AuthResult.success(
              user: authResponse.user,
              session: authResponse.session,
            );
          } else if (res.data is Map && res.data['error'] != null) {
            return AuthResult.failure(res.data['error'].toString());
          }
          return const AuthResult.failure(
            'Development email verification failed.',
          );
        } on FunctionException catch (e) {
          final details = e.details;
          final serverError = details is Map && details['error'] != null
              ? details['error'].toString()
              : (e.status == 0
                  ? 'Network connection error contacting development auth service.'
                  : (e.reasonPhrase ?? 'status ${e.status}'));
          final errorMsg = e.status == 404
              ? 'Development authentication endpoint not available (404): $serverError. Ensure ENVIRONMENT=development is configured.'
              : (e.status == 0
                  ? 'Development auth service error: Network connection error.'
                  : serverError);
          return AuthResult.failure(errorMsg);
        } catch (e) {
          return AuthResult.failure('Development auth service error: $e');
        }
      }

      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: otp.trim(),
        type: OtpType.emailChange,
      );

      if (response.user != null || response.session != null) {
        try {
          await client.auth.updateUser(
            UserAttributes(data: {'registration_completed': true}),
          );
        } catch (_) {}

        return AuthResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthResult.failure(
        'Email verification did not complete. Please retry.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to verify email OTP: $e');
    }
  }

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized.',
      );
    }

    try {
      final formattedPhone = formatIndianPhone(mobileNumber);

      // In non-production, dev-auth Edge Function is the exclusive handler
      if (_isDevMode) {
        try {
          final res = await client.functions.invoke(
            'dev-auth',
            body: {
              'action': 'send-mobile-otp',
              'mobile_number': formattedPhone,
              'is_login': true,
            },
          );
          if (res.status == 200) {
            return const AuthResult.success();
          } else if (res.data is Map && res.data['error'] != null) {
            return AuthResult.failure(res.data['error'].toString());
          }
          return const AuthResult.failure(
            'Development login OTP service returned an unexpected response.',
          );
        } on FunctionException catch (e) {
          final details = e.details;
          final serverError = details is Map && details['error'] != null
              ? details['error'].toString()
              : (e.status == 0
                  ? 'Network connection error contacting development auth service.'
                  : (e.reasonPhrase ?? 'status ${e.status}'));
          final errorMsg = e.status == 404
              ? 'Development authentication endpoint not available (404): $serverError. Ensure ENVIRONMENT=development is configured.'
              : (e.status == 0
                  ? 'Development auth service error: Network connection error.'
                  : serverError);
          return AuthResult.failure(errorMsg);
        } catch (e) {
          return AuthResult.failure('Development auth service error: $e');
        }
      }

      await client.auth.signInWithOtp(
        phone: formattedPhone,
        shouldCreateUser: false,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      final lowerMsg = e.message.toLowerCase();
      if (lowerMsg.contains('user not found') ||
          lowerMsg.contains('signups not allowed')) {
        return const AuthResult.failure(
          'No existing account found with this mobile number. Please register first.',
        );
      }
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to send login OTP: $e');
    }
  }

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult.failure(
        'Authentication service is not initialized.',
      );
    }

    try {
      final formattedPhone = formatIndianPhone(mobileNumber);

      // In non-production, dev-auth Edge Function is the exclusive handler
      if (_isDevMode) {
        try {
          final res = await client.functions.invoke(
            'dev-auth',
            body: {
              'action': 'login',
              'mobile_number': formattedPhone,
              'otp': otp.trim(),
            },
          );
          if (res.status == 200 &&
              res.data is Map &&
              res.data['token_hash'] != null) {
            final tokenHash = res.data['token_hash'].toString();
            final authResponse = await client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.magiclink,
            );
            return AuthResult.success(
              user: authResponse.user,
              session: authResponse.session,
            );
          } else if (res.data is Map && res.data['error'] != null) {
            return AuthResult.failure(res.data['error'].toString());
          }
          return const AuthResult.failure(
            'Development login verification failed.',
          );
        } on FunctionException catch (e) {
          final details = e.details;
          final serverError = details is Map && details['error'] != null
              ? details['error'].toString()
              : (e.status == 0
                  ? 'Network connection error contacting development auth service.'
                  : (e.reasonPhrase ?? 'status ${e.status}'));
          final errorMsg = e.status == 404
              ? 'Development authentication endpoint not available (404): $serverError. Ensure ENVIRONMENT=development is configured.'
              : (e.status == 0
                  ? 'Development auth service error: Network connection error.'
                  : serverError);
          return AuthResult.failure(errorMsg);
        } catch (e) {
          return AuthResult.failure('Development auth service error: $e');
        }
      }

      final response = await client.auth.verifyOTP(
        phone: formattedPhone,
        token: otp.trim(),
        type: OtpType.sms,
      );

      if (response.user != null || response.session != null) {
        return AuthResult.success(
          user: response.user,
          session: response.session,
        );
      }
      return const AuthResult.failure(
        'Login verification did not return an active session.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return AuthResult.failure('Failed to verify login OTP: $e');
    }
  }

  @override
  Future<void> signOut() async {
    _pendingRegistrationToken = null;
    _pendingRegistrationEmail = null;
    _pendingRegistrationFullName = null;
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut error: $e');
    }
  }

  /// Maps Supabase GoTrue AuthException to clear, human-readable error messages.
  static String _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }
    if (msg.contains('expired') || msg.contains('token has expired')) {
      return 'The OTP has expired. Please request a new code.';
    }
    if (msg.contains('invalid') ||
        msg.contains('token is invalid') ||
        msg.contains('bad code')) {
      return 'Invalid OTP code. Please enter the correct code.';
    }
    if (msg.contains('already registered') ||
        msg.contains('user already exists') ||
        msg.contains('unique constraint')) {
      return 'An account with this mobile number or email address already exists.';
    }
    if (msg.contains('email already in use') ||
        msg.contains('email address already taken')) {
      return 'This email address is already linked to another account.';
    }
    if (msg.contains('user not found')) {
      return 'No account found with this mobile number. Please create an account.';
    }

    return e.message;
  }
}
