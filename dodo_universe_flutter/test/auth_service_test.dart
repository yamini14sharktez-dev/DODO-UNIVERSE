import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/auth/auth_service.dart';

/// Test mock implementation for automated testing without requiring real SMS/email providers.
class MockAuthService implements IAuthService {
  bool sendRegistrationOtpCalled = false;
  bool verifyRegistrationOtpCalled = false;
  bool attachEmailCalled = false;
  bool verifyEmailOtpCalled = false;
  bool sendLoginOtpCalled = false;
  bool verifyLoginOtpCalled = false;
  bool signOutCalled = false;

  String? lastPhone;
  String? lastFullName;
  String? lastOtp;
  String? lastEmail;

  static final User _dummyUser = User.fromJson(<String, dynamic>{
    'id': 'test-user-id-123',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{'full_name': 'Rahul Sharma'},
    'aud': 'authenticated',
    'phone': '+919876543210',
    'phone_confirmed_at': '2026-11-09T00:00:00Z',
    'email': 'rahul@example.com',
    'email_confirmed_at': '2026-11-09T00:00:00Z',
    'created_at': '2026-11-09T00:00:00Z',
  })!;

  static final Session _dummySession = Session.fromJson(<String, dynamic>{
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'user': <String, dynamic>{
      'id': 'test-user-id-123',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{'full_name': 'Rahul Sharma'},
      'aud': 'authenticated',
      'phone': '+919876543210',
      'phone_confirmed_at': '2026-11-09T00:00:00Z',
      'email': 'rahul@example.com',
      'email_confirmed_at': '2026-11-09T00:00:00Z',
      'created_at': '2026-11-09T00:00:00Z',
    },
  })!;

  // Configurable return results for testing edge cases
  AuthResult registrationOtpResult = const AuthResult.success();
  AuthResult mobileVerifyResult = AuthResult.success(
    user: _dummyUser,
    session: _dummySession,
  );
  AuthResult attachEmailResult = const AuthResult.success();
  AuthResult emailVerifyResult = AuthResult.success(
    user: _dummyUser,
  );
  AuthResult loginOtpResult = const AuthResult.success();
  AuthResult loginVerifyResult = const AuthResult.success();

  User? mockUserOverride;
  bool hasUserOverride = false;
  void setMockUser(User? user) {
    mockUserOverride = user;
    hasUserOverride = true;
  }

  Session? mockSessionOverride;
  void setMockSession(Session? session) {
    mockSessionOverride = session;
  }

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  void emitAuthState(AuthState state) => _authStateController.add(state);

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  User? get currentUser =>
      hasUserOverride ? mockUserOverride : mobileVerifyResult.user;

  @override
  Session? get currentSession =>
      mockSessionOverride ?? mobileVerifyResult.session;

  bool shouldFailProfileQuery = false;
  bool isMissingProfile = false;
  bool? trustedCompletionOverride;

  @override
  Future<bool> getTrustedRegistrationStatus([User? user]) async {
    if (shouldFailProfileQuery) {
      throw const SocketException('Simulated network failure on profile query');
    }
    if (isMissingProfile) {
      return false;
    }
    if (trustedCompletionOverride != null) {
      return trustedCompletionOverride!;
    }
    return isRegistrationComplete(user);
  }

  @override
  bool isRegistrationComplete([User? user]) {
    final targetUser = user ?? currentUser;
    if (targetUser == null) return false;
    final hasPhone = targetUser.phoneConfirmedAt != null ||
        (targetUser.phone != null && targetUser.phone!.isNotEmpty);
    final hasEmail = targetUser.email != null && targetUser.email!.isNotEmpty;
    final hasConfirmedEmail = targetUser.emailConfirmedAt != null;
    return hasPhone && hasEmail && hasConfirmedEmail;
  }

  @override
  Future<AuthResult> sendRegistrationMobileOtp({
    required String fullName,
    required String mobileNumber,
    String? email,
  }) async {
    sendRegistrationOtpCalled = true;
    lastFullName = fullName;
    lastPhone = mobileNumber;
    lastEmail = email;
    return registrationOtpResult;
  }

  @override
  Future<AuthResult> verifyRegistrationMobileOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    verifyRegistrationOtpCalled = true;
    lastPhone = mobileNumber;
    lastOtp = otp;
    return mobileVerifyResult;
  }

  @override
  Future<AuthResult> attachEmail({required String email}) async {
    attachEmailCalled = true;
    lastEmail = email;
    return attachEmailResult;
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    verifyEmailOtpCalled = true;
    lastEmail = email;
    lastOtp = otp;
    return emailVerifyResult;
  }

  @override
  Future<AuthResult> sendLoginOtp({required String mobileNumber}) async {
    sendLoginOtpCalled = true;
    lastPhone = mobileNumber;
    return loginOtpResult;
  }

  @override
  Future<AuthResult> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    verifyLoginOtpCalled = true;
    lastPhone = mobileNumber;
    lastOtp = otp;
    return loginVerifyResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  group('AuthService - Unit & Phone Formatting Tests', () {
    test('formatIndianPhone formats 10-digit Indian numbers to E.164', () {
      expect(
          AuthService.formatIndianPhone('9876543210'), equals('+919876543210'));
      expect(AuthService.formatIndianPhone('+91 98765 43210'),
          equals('+919876543210'));
      expect(AuthService.formatIndianPhone('919876543210'),
          equals('+919876543210'));
    });

    test('AuthResult formats correctly', () {
      const success = AuthResult.success();
      expect(success.isSuccess, isTrue);
      expect(success.errorMessage, isNull);

      const failure = AuthResult.failure('Something went wrong');
      expect(failure.isSuccess, isFalse);
      expect(failure.errorMessage, equals('Something went wrong'));
    });
  });

  group('AuthService - Phase 5 Core Authentication Scenarios', () {
    late MockAuthService mockAuth;

    setUp(() {
      mockAuth = MockAuthService();
    });

    test('1. OTP Request: registers full name and mobile number', () async {
      final result = await mockAuth.sendRegistrationMobileOtp(
        fullName: 'Rahul Sharma',
        mobileNumber: '9876543210',
      );

      expect(mockAuth.sendRegistrationOtpCalled, isTrue);
      expect(mockAuth.lastFullName, equals('Rahul Sharma'));
      expect(mockAuth.lastPhone, equals('9876543210'));
      expect(result.isSuccess, isTrue);
    });

    test('2. Mobile Verification: verifies SMS OTP and establishes session',
        () async {
      final result = await mockAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(mockAuth.verifyRegistrationOtpCalled, isTrue);
      expect(mockAuth.lastOtp, equals('123456'));
      expect(result.isSuccess, isTrue);
      expect(result.user?.id, equals('test-user-id-123'));
      expect(result.session?.accessToken, equals('test-access-token'));
    });

    test('3. Email Attachment: links email to authenticated user', () async {
      final result = await mockAuth.attachEmail(email: 'rahul@example.com');

      expect(mockAuth.attachEmailCalled, isTrue);
      expect(mockAuth.lastEmail, equals('rahul@example.com'));
      expect(result.isSuccess, isTrue);
    });

    test('4. Email Verification: verifies email change token', () async {
      final result = await mockAuth.verifyEmailOtp(
        email: 'rahul@example.com',
        otp: '654321',
      );

      expect(mockAuth.verifyEmailOtpCalled, isTrue);
      expect(mockAuth.lastEmail, equals('rahul@example.com'));
      expect(mockAuth.lastOtp, equals('654321'));
      expect(result.isSuccess, isTrue);
    });

    test('5. Returning-user Login: sends login OTP and verifies session',
        () async {
      // Step A: Send login OTP (shouldCreateUser: false)
      final sendResult =
          await mockAuth.sendLoginOtp(mobileNumber: '9876543210');
      expect(mockAuth.sendLoginOtpCalled, isTrue);
      expect(sendResult.isSuccess, isTrue);

      // Step B: Verify SMS OTP
      final verifyResult = await mockAuth.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(mockAuth.verifyLoginOtpCalled, isTrue);
      expect(verifyResult.isSuccess, isTrue);
    });

    test('6. Invalid OTP: returns appropriate failure result', () async {
      mockAuth.mobileVerifyResult = const AuthResult.failure(
        'Invalid OTP code. Please enter the correct code.',
      );

      final result = await mockAuth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '000000',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid OTP code'));
    });

    test('7. Expired OTP: returns token expiration notice', () async {
      mockAuth.emailVerifyResult = const AuthResult.failure(
        'The OTP has expired. Please request a new code.',
      );

      final result = await mockAuth.verifyEmailOtp(
        email: 'rahul@example.com',
        otp: '999999',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('expired'));
    });

    test('8. Duplicate Registration: handles existing account gracefully',
        () async {
      mockAuth.registrationOtpResult = const AuthResult.failure(
        'An account with this mobile number or email address already exists.',
      );

      final result = await mockAuth.sendRegistrationMobileOtp(
        fullName: 'Rahul Sharma',
        mobileNumber: '9876543210',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('already exists'));
    });

    test('9. Network Errors: returns connectivity message', () async {
      mockAuth.loginOtpResult = const AuthResult.failure(
        'Network error. Please check your internet connection.',
      );

      final result = await mockAuth.sendLoginOtp(mobileNumber: '9876543210');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Network error'));
    });

    test('10. Resend OTP: triggers subsequent OTP request', () async {
      // First send
      await mockAuth.sendRegistrationMobileOtp(
        fullName: 'Rahul Sharma',
        mobileNumber: '9876543210',
      );
      expect(mockAuth.sendRegistrationOtpCalled, isTrue);

      // Resend
      mockAuth.sendRegistrationOtpCalled = false;
      await mockAuth.sendRegistrationMobileOtp(
        fullName: 'Rahul Sharma',
        mobileNumber: '9876543210',
      );
      expect(mockAuth.sendRegistrationOtpCalled, isTrue);
    });

    test('Sign Out: executes cleanly', () async {
      await mockAuth.signOut();
      expect(mockAuth.signOutCalled, isTrue);
    });
  });

  group('AuthService – Development OTP Edge Function vs Production Isolation',
      () {
    late List<http.BaseRequest> recordedRequests;
    late List<String> recordedBodies;

    TestMockHttpClient createMockClient({
      int devAuthStatus = 200,
      Map<String, dynamic>? devAuthBody,
      http.StreamedResponse Function(
              http.BaseRequest request, Map<String, dynamic> bodyJson)?
          devAuthHandler,
      bool throwNetworkException = false,
      int authStatus = 200,
      Map<String, dynamic>? authBody,
    }) {
      return TestMockHttpClient((request) async {
        recordedRequests.add(request);

        String bodyStr = '';
        if (request is http.Request) {
          bodyStr = request.body;
        }
        recordedBodies.add(bodyStr);

        if (throwNetworkException) {
          throw const SocketException('Simulated network connection failure');
        }

        if (request.url.path.contains('/functions/v1/dev-auth')) {
          if (devAuthHandler != null) {
            Map<String, dynamic> jsonBody = {};
            try {
              jsonBody = jsonDecode(bodyStr) as Map<String, dynamic>;
            } catch (_) {}
            return devAuthHandler(request, jsonBody);
          }
          final payload = jsonEncode(devAuthBody ?? {'success': true});
          return http.StreamedResponse(
            Stream.value(utf8.encode(payload)),
            devAuthStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('/auth/v1/otp') ||
            request.url.path.contains('/auth/v1/verify')) {
          final payload = jsonEncode(authBody ??
              {
                'access_token': 'test_token',
                'token_type': 'bearer',
                'user': {
                  'id': 'user_123',
                  'phone': '+919876543210',
                  'aud': 'authenticated',
                },
              });
          return http.StreamedResponse(
            Stream.value(utf8.encode(payload)),
            authStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.StreamedResponse(
          Stream.value(utf8.encode('{}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    }

    setUp(() {
      recordedRequests = [];
      recordedBodies = [];
    });

    test(
        '1. sendRegistrationMobileOtp (dev mode) calls dev-auth and succeeds without calling SMS OTP',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 200,
        devAuthBody: {'success': true, 'message': 'Development OTP ready'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.sendRegistrationMobileOtp(
        fullName: 'Rahul Dev',
        mobileNumber: '9876543210',
        email: 'rahul@dev.edu',
      );

      expect(result.isSuccess, isTrue);
      // Dev-auth invoked
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isTrue);
      // Built-in Supabase phone OTP MUST NOT be invoked
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isFalse);
    });

    test(
        '2. sendRegistrationMobileOtp (dev mode) fails cleanly on HTTP 404 without falling through to SMS',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 404,
        devAuthBody: {'error': 'Endpoint not available'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.sendRegistrationMobileOtp(
        fullName: 'Rahul Dev',
        mobileNumber: '9876543210',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('404'));
      // dev-auth was called
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isTrue);
      // Built-in SMS auth MUST NOT be called!
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isFalse);
    });

    test(
        '3. sendRegistrationMobileOtp (dev mode) fails cleanly on network exception without falling through to SMS',
        () async {
      final mockHttp = createMockClient(throwNetworkException: true);
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.sendRegistrationMobileOtp(
        fullName: 'Rahul Dev',
        mobileNumber: '9876543210',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Development auth service error'));
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isFalse);
    });

    test(
        '4. verifyRegistrationMobileOtp (dev mode) calls dev-auth and never calls GoTrue SMS verify',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 200,
        devAuthBody: {
          'success': true,
          'registration_token': 'dev_reg_token_123'
        },
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isTrue);
      expect(
          recordedRequests.any((r) => r.url.path.contains('/auth/v1/verify')),
          isFalse);
    });

    test(
        '5. verifyRegistrationMobileOtp (dev mode) fails cleanly on 404 without falling through to GoTrue SMS verify',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 404,
        devAuthBody: {'error': 'Endpoint not available'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('404'));
      expect(
          recordedRequests.any((r) => r.url.path.contains('/auth/v1/verify')),
          isFalse);
    });

    test(
        '6. sendLoginOtp (dev mode) calls dev-auth with is_login: true and never calls GoTrue SMS OTP',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 200,
        devAuthBody: {'success': true, 'message': 'Development OTP ready'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.sendLoginOtp(mobileNumber: '9876543210');

      expect(result.isSuccess, isTrue);
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isTrue);
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isFalse);
    });

    test(
        '7. sendLoginOtp (dev mode) fails cleanly on 404 without falling through to GoTrue SMS OTP',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 404,
        devAuthBody: {'error': 'Endpoint not available'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.sendLoginOtp(mobileNumber: '9876543210');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('404'));
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isFalse);
    });

    test(
        '8. verifyLoginOtp (dev mode) fails cleanly on 404 without falling through to GoTrue SMS verify',
        () async {
      final mockHttp = createMockClient(
        devAuthStatus: 404,
        devAuthBody: {'error': 'Endpoint not available'},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: true);

      final result = await auth.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('404'));
      expect(
          recordedRequests.any((r) => r.url.path.contains('/auth/v1/verify')),
          isFalse);
    });

    test(
        '9. Production Mode (isDevMode: false) uses built-in Supabase phone authentication directly',
        () async {
      final mockHttp = createMockClient(
        authStatus: 200,
        authBody: {},
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: false);

      final result = await auth.sendRegistrationMobileOtp(
        fullName: 'Prod User',
        mobileNumber: '9876543210',
        email: 'prod@company.com',
      );

      expect(result.isSuccess, isTrue);
      // dev-auth MUST NOT be called in production
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isFalse);
      // Native GoTrue phone OTP MUST be called in production
      expect(recordedRequests.any((r) => r.url.path.contains('/auth/v1/otp')),
          isTrue);
    });

    test(
        '10. Production Mode verifyRegistrationMobileOtp uses GoTrue SMS verify directly',
        () async {
      final mockHttp = createMockClient(
        authStatus: 200,
        authBody: {
          'access_token': 'prod_token',
          'token_type': 'bearer',
          'user': {
            'id': 'prod_user_1',
            'phone': '+919876543210',
            'aud': 'authenticated',
          },
        },
      );
      final client = SupabaseClient(
          'https://swivkawtnqymvymjxlpl.supabase.co', 'test-key',
          httpClient: mockHttp);
      final auth = AuthService(client: client, isDevMode: false);

      final result = await auth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '999888',
      );

      expect(result.isSuccess, isTrue);
      expect(
          recordedRequests
              .any((r) => r.url.path.contains('/functions/v1/dev-auth')),
          isFalse);
      expect(
          recordedRequests.any((r) => r.url.path.contains('/auth/v1/verify')),
          isTrue);
    });

    test(
        '11. Registration Scenario A: Email provided during initial mobile registration is passed to dev-auth verify-mobile-otp and completes email verification',
        () async {
      final mockHttp = createMockClient(
        devAuthHandler: (request, bodyJson) {
          final action = bodyJson['action'];
          if (action == 'send-mobile-otp') {
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(
                  {'success': true, 'message': 'Development OTP ready'}))),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (action == 'verify-mobile-otp') {
            // Verify that email and full_name are included in the payload
            expect(bodyJson['email'], equals('alice@test.edu'));
            expect(bodyJson['full_name'], equals('Alice Sharma'));
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'success': true,
                'registration_token': 'dev_token_alice_123'
              }))),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (action == 'verify-email-otp') {
            expect(bodyJson['email'], equals('alice@test.edu'));
            expect(bodyJson['otp'], equals('123456'));
            expect(
                bodyJson['registration_token'], equals('dev_token_alice_123'));
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(
                  {'success': true, 'token_hash': 'alice_token_hash'}))),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            400,
            headers: {'content-type': 'application/json'},
          );
        },
      );

      final client = SupabaseClient(
        'https://swivkawtnqymvymjxlpl.supabase.co',
        'test-key',
        httpClient: mockHttp,
      );
      final auth = AuthService(client: client, isDevMode: true);

      // Step 1: Send registration mobile OTP with email
      final sendResult = await auth.sendRegistrationMobileOtp(
        fullName: 'Alice Sharma',
        mobileNumber: '9876543210',
        email: 'alice@test.edu',
      );
      expect(sendResult.isSuccess, isTrue);

      // Step 2: Verify mobile OTP (should carry forward email and full_name to dev-auth)
      final mobileResult = await auth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(mobileResult.isSuccess, isTrue);

      // Step 3: Verify email OTP with development OTP 123456
      final emailResult = await auth.verifyEmailOtp(
        email: 'alice@test.edu',
        otp: '123456',
      );
      expect(emailResult.isSuccess, isTrue);
      expect(emailResult.session?.accessToken, equals('test_token'));
    });

    test(
        '12. Registration Scenario B: Email omitted during initial registration, attached via attachEmail, and verified via dev-auth',
        () async {
      final mockHttp = createMockClient(
        devAuthHandler: (request, bodyJson) {
          final action = bodyJson['action'];
          if (action == 'send-mobile-otp') {
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(
                  {'success': true, 'message': 'Development OTP ready'}))),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (action == 'verify-mobile-otp') {
            // Email was not provided initially
            expect(bodyJson.containsKey('email'), isFalse);
            expect(bodyJson['full_name'], equals('Bob Kumar'));
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'success': true,
                'registration_token': 'dev_token_bob_456'
              }))),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (action == 'verify-email-otp') {
            // Email attached later
            expect(bodyJson['email'], equals('bob@test.edu'));
            expect(bodyJson['otp'], equals('123456'));
            expect(bodyJson['registration_token'], equals('dev_token_bob_456'));
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(
                  {'success': true, 'token_hash': 'bob_token_hash'}))),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            400,
            headers: {'content-type': 'application/json'},
          );
        },
      );

      final client = SupabaseClient(
        'https://swivkawtnqymvymjxlpl.supabase.co',
        'test-key',
        httpClient: mockHttp,
      );
      final auth = AuthService(client: client, isDevMode: true);

      // Step 1: Send registration mobile OTP without email
      final sendResult = await auth.sendRegistrationMobileOtp(
        fullName: 'Bob Kumar',
        mobileNumber: '9876543210',
      );
      expect(sendResult.isSuccess, isTrue);

      // Step 2: Verify mobile OTP
      final mobileResult = await auth.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(mobileResult.isSuccess, isTrue);

      // Step 3: Attach email subsequently
      final attachResult = await auth.attachEmail(email: 'bob@test.edu');
      expect(attachResult.isSuccess, isTrue);

      // Step 4: Verify email OTP with development OTP 123456
      final emailResult = await auth.verifyEmailOtp(
        email: 'bob@test.edu',
        otp: '123456',
      );
      expect(emailResult.isSuccess, isTrue);
      expect(emailResult.session?.accessToken, equals('test_token'));
    });
  });
}

class TestMockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;

  TestMockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
