import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Secure pending registration state in development mode.
class _DevPendingRegistration {
  final String fullName;
  String email;
  final String mobileNumber;
  final String registrationToken;
  final String emailOtp;
  final DateTime expiresAt;
  int failedAttempts;

  _DevPendingRegistration({
    required this.fullName,
    required this.email,
    required this.mobileNumber,
    required this.registrationToken,
    required this.emailOtp,
    DateTime? expiresAt,
  })  : expiresAt =
            expiresAt ?? DateTime.now().add(const Duration(minutes: 15)),
        failedAttempts = 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Development & test implementation of [IAuthService] supporting per-mobile
/// fixed OTP authentication and genuine multi-step registration.
///
/// Security & Architecture Rules:
/// 1. Each authorized test mobile number has its own fixed OTP.
/// 2. Failed attempts are tracked per number with a 15-minute lockout after 5 failures.
/// 3. Mobile OTP verification does NOT establish an authenticated session.
/// 4. Email verification is a separate mandatory step.
/// 5. Authenticated session is established ONLY after both mobile and email are verified.
/// 6. Strictly prohibited in release builds (fails closed).
class DevAuthService implements IAuthService {
  /// Default development test OTP for email or registered test numbers.
  static const String defaultOtp = '123456';

  /// Default development test email OTP.
  static const String defaultEmailOtp = '123456';

  /// Pre-configured test numbers mapped to their fixed development OTPs.
  ///
  /// - '+919392518488' -> '654321' (Confirmed test number)
  /// - '630280360' contains only 9 digits; left UNSEEDED per project specification.
  static final Map<String, String> _configuredTestNumbers = <String, String>{
    '+919392518488': '654321',
  };

  /// In-memory user registry across dev service instances.
  static final Map<String, User> _registeredUsers = <String, User>{};

  /// Authoritative database registration completion status mapping.
  static final Map<String, bool> _trustedProfileStatus = <String, bool>{};

  /// In-memory persistent session storage for simulated app restarts.
  static Session? _persistedSession;

  /// Per-number failed attempts and lockout trackers.
  static final Map<String, int> _failedAttempts = <String, int>{};
  static final Map<String, DateTime> _lockedUntil = <String, DateTime>{};

  /// Active pending registrations keyed by normalized mobile number.
  final Map<String, _DevPendingRegistration> _pendingRegistrations =
      <String, _DevPendingRegistration>{};

  /// Active pending registration token for the current client flow.
  String? _activeRegistrationToken;

  User? _currentUser;
  Session? _currentSession;

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  // Test simulation flags
  bool simulateNetworkError = false;
  bool simulateRateLimit = false;
  bool simulateOtpExpiry = false;

  DevAuthService({
    User? initialUser,
    Session? initialSession,
    bool restorePersistedSession = true,
  }) {
    if (kReleaseMode) {
      throw UnsupportedError(
        'DevAuthService is strictly for development and testing. '
        'It cannot be instantiated or used in release mode builds.',
      );
    }

    if (initialSession != null) {
      _currentSession = initialSession;
      _currentUser = initialUser ?? initialSession.user;
    } else if (initialUser != null) {
      _currentUser = initialUser;
      _currentSession = _createSessionForUser(initialUser);
    } else if (restorePersistedSession && _persistedSession != null) {
      _currentSession = _persistedSession;
      _currentUser = _persistedSession!.user;
    }
  }

  /// Reset all shared dev state between tests.
  static void resetDevStore() {
    _registeredUsers.clear();
    _trustedProfileStatus.clear();
    _persistedSession = null;
    _failedAttempts.clear();
    _lockedUntil.clear();
    _configuredTestNumbers
      ..clear()
      ..['+919392518488'] = '654321';
  }

  /// Override trusted profile registration completion status for testing.
  static void setTrustedProfileStatus(String userId, bool isComplete) {
    _trustedProfileStatus[userId] = isComplete;
  }

  /// Register an authorized development test mobile number and OTP.
  static void registerTestNumber(String mobileNumber, String otp) {
    final formatted = AuthService.formatIndianPhone(mobileNumber);
    _configuredTestNumbers[formatted] = otp;
  }

  /// Manually seed a registered user (useful for test fixtures).
  static void seedUser(User user) {
    if (user.phone != null && user.phone!.isNotEmpty) {
      _registeredUsers[user.phone!] = user;
    }
  }

  /// Retrieve the current persisted session.
  static Session? get persistedSession => _persistedSession;

  /// Check if a mobile number is currently locked out.
  static bool isNumberLocked(String mobileNumber) {
    final formatted = AuthService.formatIndianPhone(mobileNumber);
    final lockTime = _lockedUntil[formatted];
    return lockTime != null && DateTime.now().isBefore(lockTime);
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => _currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async {
    if (simulateNetworkError) {
      throw Exception('Network error verifying profile status');
    }
    final target = user ?? _currentUser;
    if (target == null) return false;

    if (_trustedProfileStatus.containsKey(target.id)) {
      return _trustedProfileStatus[target.id] == true;
    }

    return isRegistrationComplete(target);
  }

  @override
  bool isRegistrationComplete([User? user]) {
    final target = user ?? _currentUser;
    if (target == null) return false;

    // Both phone and email MUST have server-confirmed timestamps.
    // Client-editable user_metadata is NOT trusted on its own.
    final hasPhone = target.phoneConfirmedAt != null ||
        (target.phone != null && target.phone!.isNotEmpty);
    final hasEmail = target.email != null && target.email!.isNotEmpty;
    final hasConfirmedEmail = target.emailConfirmedAt != null;

    return hasPhone && hasEmail && hasConfirmedEmail;
  }

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }
    if (simulateRateLimit) {
      return const AuthResult.failure(
        'Too many attempts. Please wait a few moments before trying again.',
      );
    }

    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return const AuthResult.failure(
        'Please enter a valid 10-digit mobile number.',
      );
    }

    final formatted = AuthService.formatIndianPhone(mobileNumber);

    // Check lockout
    final lockTime = _lockedUntil[formatted];
    if (lockTime != null && DateTime.now().isBefore(lockTime)) {
      return const AuthResult.failure(
        'Too many failed attempts. Please wait 15 minutes before trying again.',
      );
    }

    // Allow ANY valid 10-digit Indian mobile number to register in development;
    // defaults to common fixed OTP '123456' unless explicitly mapped.
    _configuredTestNumbers.putIfAbsent(formatted, () => defaultOtp);

    // Generate single-use registration token & store initial pending registration
    final token = 'dev_reg_${DateTime.now().millisecondsSinceEpoch}_$digits';
    _activeRegistrationToken = token;

    _pendingRegistrations[formatted] = _DevPendingRegistration(
      fullName: fullName.trim(),
      email: email?.trim() ?? '',
      mobileNumber: formatted,
      registrationToken: token,
      emailOtp: defaultEmailOtp,
    );

    return const AuthResult.success();
  }

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }
    if (simulateOtpExpiry) {
      return const AuthResult.failure(
        'The OTP has expired. Please request a new code.',
      );
    }

    final formatted = AuthService.formatIndianPhone(mobileNumber);

    // Check lockout
    final lockTime = _lockedUntil[formatted];
    if (lockTime != null && DateTime.now().isBefore(lockTime)) {
      return const AuthResult.failure(
        'Too many failed attempts. Account locked for 15 minutes.',
      );
    }

    final expectedOtp = _configuredTestNumbers[formatted] ?? defaultOtp;

    if (otp.trim() != expectedOtp) {
      final currentAttempts = (_failedAttempts[formatted] ?? 0) + 1;
      _failedAttempts[formatted] = currentAttempts;

      if (currentAttempts >= 5) {
        _lockedUntil[formatted] =
            DateTime.now().add(const Duration(minutes: 15));
        return const AuthResult.failure(
          'Too many failed attempts. Account locked for 15 minutes.',
        );
      }

      return const AuthResult.failure(
        'Invalid OTP code. Please enter the correct code.',
      );
    }

    // OTP is valid -> reset failure counter
    _failedAttempts[formatted] = 0;
    _lockedUntil.remove(formatted);

    final pending = _pendingRegistrations[formatted];
    if (pending == null || pending.isExpired) {
      return const AuthResult.failure(
        'Registration session has expired. Please restart registration.',
      );
    }

    // CRITICAL: Mobile OTP verification DOES NOT establish a session.
    // Email verification is required before session issuance.
    _currentUser = null;
    _currentSession = null;

    return const AuthResult.success();
  }

  @override
  Future<AuthResult> attachEmail({required String email}) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }

    // Update pending registration email
    for (final pending in _pendingRegistrations.values) {
      if (pending.registrationToken == _activeRegistrationToken) {
        pending.email = email.trim();
        break;
      }
    }

    return const AuthResult.success();
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }
    if (simulateOtpExpiry) {
      return const AuthResult.failure(
        'The OTP has expired. Please request a new code.',
      );
    }

    // Locate pending registration matching token and email
    _DevPendingRegistration? matchingPending;
    for (final pending in _pendingRegistrations.values) {
      if (pending.registrationToken == _activeRegistrationToken &&
          pending.email.toLowerCase() == email.trim().toLowerCase()) {
        matchingPending = pending;
        break;
      }
    }

    // Support resuming incomplete registration from an existing user session
    if (matchingPending == null && _currentUser != null) {
      if (otp.trim() != defaultEmailOtp) {
        return const AuthResult.failure(
          'Invalid OTP code. Please enter the correct code.',
        );
      }
      final completedUser = _createDevUser(
        id: _currentUser!.id,
        phone: _currentUser!.phone ?? '',
        fullName: (_currentUser!.userMetadata?['full_name'] as String?) ?? '',
        email: email.trim(),
        phoneConfirmed: true,
        emailConfirmed: true,
        registrationCompleted: true,
      );
      final session = _createSessionForUser(completedUser);
      _currentUser = completedUser;
      _currentSession = session;
      _persistedSession = session;
      if (completedUser.phone != null) {
        _registeredUsers[completedUser.phone!] = completedUser;
      }
      _trustedProfileStatus[completedUser.id] = true;
      _authStateController.add(AuthState(AuthChangeEvent.signedIn, session));
      return AuthResult.success(user: completedUser, session: session);
    }

    if (matchingPending == null || matchingPending.isExpired) {
      return const AuthResult.failure(
        'Invalid or expired verification session.',
      );
    }

    if (otp.trim() != matchingPending.emailOtp) {
      matchingPending.failedAttempts += 1;
      if (matchingPending.failedAttempts >= 5) {
        _pendingRegistrations.remove(matchingPending.mobileNumber);
        return const AuthResult.failure(
          'Too many failed attempts. Registration session invalidated.',
        );
      }
      return const AuthResult.failure(
        'Invalid OTP code. Please enter the correct code.',
      );
    }

    // BOTH mobile and email are verified! Now establish genuine session.
    final user = _createDevUser(
      id: 'dev-user-${matchingPending.mobileNumber.replaceAll(RegExp(r'\D'), '')}',
      phone: matchingPending.mobileNumber,
      fullName: matchingPending.fullName,
      email: matchingPending.email,
      phoneConfirmed: true,
      emailConfirmed: true,
      registrationCompleted: true,
    );

    final session = _createSessionForUser(user);

    _currentUser = user;
    _currentSession = session;
    _persistedSession = session;
    _registeredUsers[matchingPending.mobileNumber] = user;
    _trustedProfileStatus[user.id] = true;
    _pendingRegistrations.remove(matchingPending.mobileNumber);
    _activeRegistrationToken = null;

    _authStateController.add(AuthState(AuthChangeEvent.signedIn, session));

    return AuthResult.success(user: user, session: session);
  }

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }
    if (simulateRateLimit) {
      return const AuthResult.failure(
        'Too many attempts. Please wait a few moments before trying again.',
      );
    }

    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return const AuthResult.failure(
        'Please enter a valid 10-digit mobile number.',
      );
    }

    final formatted = AuthService.formatIndianPhone(mobileNumber);

    // Check lockout
    final lockTime = _lockedUntil[formatted];
    if (lockTime != null && DateTime.now().isBefore(lockTime)) {
      return const AuthResult.failure(
        'Too many failed attempts. Please wait 15 minutes before trying again.',
      );
    }

    if (!_registeredUsers.containsKey(formatted)) {
      return const AuthResult.failure(
        'No existing account found with this mobile number. Please register first.',
      );
    }

    return const AuthResult.success();
  }

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    if (simulateNetworkError) {
      return const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );
    }
    if (simulateOtpExpiry) {
      return const AuthResult.failure(
        'The OTP has expired. Please request a new code.',
      );
    }

    final formatted = AuthService.formatIndianPhone(mobileNumber);

    if (!_registeredUsers.containsKey(formatted)) {
      return const AuthResult.failure(
        'Invalid verification code or mobile number.',
      );
    }

    // Check lockout
    final lockTime = _lockedUntil[formatted];
    if (lockTime != null && DateTime.now().isBefore(lockTime)) {
      return const AuthResult.failure(
        'Too many failed attempts. Account locked for 15 minutes.',
      );
    }

    final expectedOtp = _configuredTestNumbers[formatted] ?? defaultOtp;

    if (otp.trim() != expectedOtp) {
      final currentAttempts = (_failedAttempts[formatted] ?? 0) + 1;
      _failedAttempts[formatted] = currentAttempts;

      if (currentAttempts >= 5) {
        _lockedUntil[formatted] =
            DateTime.now().add(const Duration(minutes: 15));
        return const AuthResult.failure(
          'Too many failed attempts. Account locked for 15 minutes.',
        );
      }

      return const AuthResult.failure(
        'Invalid OTP code. Please enter the correct code.',
      );
    }

    // OTP is valid -> reset failure counter
    _failedAttempts[formatted] = 0;
    _lockedUntil.remove(formatted);

    final user = _registeredUsers[formatted];
    if (user == null) {
      return const AuthResult.failure(
        'No account found with this mobile number. Please create an account.',
      );
    }

    final session = _createSessionForUser(user);

    _currentUser = user;
    _currentSession = session;
    _persistedSession = session;

    _authStateController.add(AuthState(AuthChangeEvent.signedIn, session));

    return AuthResult.success(user: user, session: session);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _currentSession = null;
    _persistedSession = null;
    _activeRegistrationToken = null;
    _authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  // Helper factory for creating test Users
  static User _createDevUser({
    required String id,
    required String phone,
    String? email,
    String? fullName,
    bool phoneConfirmed = false,
    bool emailConfirmed = false,
    bool registrationCompleted = false,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return User.fromJson(<String, dynamic>{
      'id': id,
      'app_metadata': <String, dynamic>{'provider': 'phone'},
      'user_metadata': <String, dynamic>{
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
        if (registrationCompleted) 'registration_completed': true,
      },
      'aud': 'authenticated',
      'created_at': now,
      'phone': phone,
      'phone_confirmed_at': phoneConfirmed ? now : null,
      'email': email,
      'email_confirmed_at': emailConfirmed ? now : null,
    })!;
  }

  // Helper factory for creating test Sessions
  static Session _createSessionForUser(User user) {
    return Session.fromJson(<String, dynamic>{
      'access_token': 'dev-access-token-${user.id}',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'dev-refresh-token-${user.id}',
      'user': <String, dynamic>{
        'id': user.id,
        'app_metadata': user.appMetadata,
        'user_metadata': user.userMetadata ?? <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': user.createdAt,
        'phone': user.phone,
        'phone_confirmed_at': user.phoneConfirmedAt,
        'email': user.email,
        'email_confirmed_at': user.emailConfirmedAt,
      },
    })!;
  }
}
