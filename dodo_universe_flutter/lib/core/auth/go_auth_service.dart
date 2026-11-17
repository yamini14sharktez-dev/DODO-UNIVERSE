import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Pure Go backend implementation of IAuthService for DODO Universe.
class GoAuthService implements IAuthService {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return _uuidRegex.hasMatch(id.trim());
  }

  final ApiClient apiClient;

  String? _registrationToken;
  String? _pendingEmail;
  String? _pendingFullName;

  User? _currentUser;
  Session? _currentSession;
  bool _isRegistrationCompleted = false;

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  GoAuthService({
    required this.apiClient,
  });

  static GoAuthService? _instance;
  static GoAuthService get instance => _instance ??= GoAuthService.create();
  static set instance(GoAuthService service) => _instance = service;

  factory GoAuthService.create({String? baseUrl, ApiClient? client}) {
    final effectiveBaseUrl = baseUrl ?? AppConfig.current().apiBaseUrl;
    return GoAuthService(
      apiClient: client ?? ApiClient(baseUrl: effectiveBaseUrl),
    );
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => _currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  bool isRegistrationComplete([User? user]) {
    if (user != null) {
      if (user.userMetadata != null &&
          user.userMetadata!.containsKey('is_registration_complete')) {
        return user.userMetadata!['is_registration_complete'] == true;
      }
      final hasPhone = user.phoneConfirmedAt != null ||
          (user.phone != null && user.phone!.isNotEmpty);
      final hasEmail = user.email != null && user.email!.isNotEmpty;
      final hasConfirmedEmail = user.emailConfirmedAt != null;
      return hasPhone && hasEmail && hasConfirmedEmail;
    }
    return _isRegistrationCompleted;
  }

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async {
    if (!apiClient.isAuthenticated) return false;
    try {
      final res = await apiClient.get('/api/v1/auth/me');
      if (res is Map) {
        _isRegistrationCompleted = res['is_registration_complete'] == true;
        _updateLocalUserFromMe(res);
        return _isRegistrationCompleted;
      }
      return false;
    } catch (_) {
      return isRegistrationComplete(user);
    }
  }

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async {
    try {
      _pendingFullName = fullName.trim();
      _pendingEmail = email?.trim();

      await apiClient.post(
        '/api/v1/auth/register/send-otp',
        body: {
          'full_name': fullName.trim(),
          'mobile_number': AuthService.formatIndianPhone(mobileNumber),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
      );
      return const AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to send OTP: $e');
    }
  }

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/auth/register/verify-mobile',
        body: {
          'mobile_number': AuthService.formatIndianPhone(mobileNumber),
          'otp': otp.trim(),
          if (_pendingFullName != null) 'full_name': _pendingFullName,
          if (_pendingEmail != null && _pendingEmail!.isNotEmpty)
            'email': _pendingEmail,
        },
      );

      if (res is Map && res['registration_token'] != null) {
        _registrationToken = res['registration_token'].toString();
        return const AuthResult.success();
      }
      return const AuthResult.failure('Mobile verification failed.');
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to verify mobile OTP: $e');
    }
  }

  @override
  Future<AuthResult> attachEmail({required String email}) async {
    _pendingEmail = email.trim();
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    if (_registrationToken == null) {
      return const AuthResult.failure(
        'Registration session missing or expired. Please restart registration.',
      );
    }

    try {
      final res = await apiClient.post(
        '/api/v1/auth/register/verify-email',
        body: {
          'registration_token': _registrationToken,
          'email': email.trim(),
          'otp': otp.trim(),
        },
      );

      if (res is Map) {
        final authError = _handleAuthSuccess(res);
        if (authError != null) {
          return AuthResult.failure(authError);
        }
        _registrationToken = null;
        _pendingEmail = null;
        _pendingFullName = null;
        return AuthResult.success(user: _currentUser, session: _currentSession);
      }
      return const AuthResult.failure('Email verification failed.');
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to verify email OTP: $e');
    }
  }

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async {
    try {
      await apiClient.post(
        '/api/v1/auth/login/send-otp',
        body: {
          'mobile_number': AuthService.formatIndianPhone(mobileNumber),
        },
      );
      return const AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to send login OTP: $e');
    }
  }

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/auth/login/verify-otp',
        body: {
          'mobile_number': AuthService.formatIndianPhone(mobileNumber),
          'otp': otp.trim(),
        },
      );

      if (res is Map) {
        final authError = _handleAuthSuccess(res);
        if (authError != null) {
          return AuthResult.failure(authError);
        }
        return AuthResult.success(user: _currentUser, session: _currentSession);
      }
      return const AuthResult.failure('Login verification failed.');
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to verify login OTP: $e');
    }
  }

  @override
  Future<void> signOut() async {
    final refresh = apiClient.refreshToken;
    if (refresh != null) {
      try {
        await apiClient
            .post('/api/v1/auth/logout', body: {'refresh_token': refresh});
      } catch (_) {}
    }
    apiClient.clearTokens();
    _currentUser = null;
    _currentSession = null;
    _registrationToken = null;
    _isRegistrationCompleted = false;
    _authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  /// Validates the authentication response payload and establishes
  /// the active user session and token storage.
  ///
  /// Returns null on success, or an error description string on failure.
  String? _handleAuthSuccess(Map data) {
    final tokens = data['tokens'];
    if (tokens is! Map) {
      return 'Invalid authentication response: missing tokens payload.';
    }

    final rawAccess = tokens['access_token'];
    if (rawAccess is! String || rawAccess.trim().isEmpty) {
      return 'Invalid authentication response: missing or empty access token.';
    }
    final accessToken = rawAccess.trim();

    final rawRefresh = tokens['refresh_token'];
    if (rawRefresh is! String || rawRefresh.trim().isEmpty) {
      return 'Invalid authentication response: missing or empty refresh token.';
    }
    final refreshToken = rawRefresh.trim();

    final userData = data['user'];
    if (userData is! Map) {
      return 'Invalid authentication response: missing user payload.';
    }

    final rawId = userData['id'];
    if (rawId is! String || !_isValidUuid(rawId.trim())) {
      return 'Invalid authentication response: missing or invalid user ID.';
    }
    final userId = rawId.trim();

    final isComplete = userData['is_registration_complete'] == true;
    _isRegistrationCompleted = isComplete;

    final phone = userData['phone']?.toString();
    final email = userData['email']?.toString();
    final fullName = userData['full_name']?.toString() ?? '';
    final phoneConfirmedAt = userData['phone_confirmed_at']?.toString();
    final emailConfirmedAt = userData['email_confirmed_at']?.toString();
    final createdAt = userData['created_at']?.toString() ?? '';

    // Persist genuine tokens to ApiClient and underlying TokenStorage
    apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);

    final userMap = <String, dynamic>{
      'id': userId,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{
        'full_name': fullName,
        'is_registration_complete': isComplete,
      },
      'aud': 'authenticated',
      'phone': phone,
      'phone_confirmed_at': phoneConfirmedAt,
      'email': email,
      'email_confirmed_at': emailConfirmedAt,
      'created_at': createdAt,
    };

    _currentUser = User.fromJson(userMap);

    _currentSession = Session.fromJson(<String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'bearer',
      'user': userMap,
    });

    _authStateController
        .add(AuthState(AuthChangeEvent.signedIn, _currentSession));
    return null;
  }

  void _updateLocalUserFromMe(Map userData) {
    final rawId = userData['id'];
    if (rawId is! String || !_isValidUuid(rawId.trim())) {
      return;
    }
    final userId = rawId.trim();

    final isComplete = userData['is_registration_complete'] == true;
    _isRegistrationCompleted = isComplete;

    final phone = userData['phone']?.toString();
    final email = userData['email']?.toString();
    final fullName = userData['full_name']?.toString() ?? '';
    final phoneConfirmedAt = userData['phone_confirmed_at']?.toString();
    final emailConfirmedAt = userData['email_confirmed_at']?.toString();
    final createdAt = userData['created_at']?.toString() ?? '';

    final userMap = <String, dynamic>{
      'id': userId,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{
        'full_name': fullName,
        'is_registration_complete': isComplete,
      },
      'aud': 'authenticated',
      'phone': phone,
      'phone_confirmed_at': phoneConfirmedAt,
      'email': email,
      'email_confirmed_at': emailConfirmedAt,
      'created_at': createdAt,
    };

    _currentUser = User.fromJson(userMap);

    final accessToken = apiClient.accessToken;
    final refreshToken = apiClient.refreshToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      _currentSession = Session.fromJson(<String, dynamic>{
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': 'bearer',
        'user': userMap,
      });
    }
  }
}
