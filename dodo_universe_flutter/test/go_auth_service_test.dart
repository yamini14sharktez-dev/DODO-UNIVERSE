import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dodo_universe/core/api/api_client.dart';
import 'package:dodo_universe/core/auth/go_auth_service.dart';

void main() {
  group('GoAuthService - Flutter to Go Backend Integration Tests', () {
    late List<http.BaseRequest> recordedRequests;
    late List<String> recordedBodies;

    const validUserId = 'e9b3a042-491a-4c28-986f-3df15e19f18a';

    TestMockClient createMockClient({
      int sendOtpStatus = 200,
      int verifyMobileStatus = 200,
      int verifyEmailStatus = 200,
      Map<String, dynamic>? customVerifyEmailData,
      int sendLoginStatus = 200,
      int verifyLoginStatus = 200,
      Map<String, dynamic>? customVerifyLoginData,
    }) {
      return TestMockClient((request) async {
        recordedRequests.add(request);
        String body = '';
        if (request is http.Request) {
          body = request.body;
        }
        recordedBodies.add(body);

        final path = request.url.path;

        if (path.contains('/api/v1/auth/register/send-otp')) {
          if (sendOtpStatus == 200) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'message': 'OTP sent successfully'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'USER_EXISTS',
                'message': 'An account already exists.'
              },
            }),
            sendOtpStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/api/v1/auth/register/verify-mobile')) {
          if (verifyMobileStatus == 200) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'registration_token': 'go_reg_token_abc123',
                  'mobile_verified': true,
                  'message': 'Mobile verified successfully',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'INVALID_OTP', 'message': 'Invalid OTP code.'},
            }),
            verifyMobileStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/api/v1/auth/register/verify-email')) {
          if (verifyEmailStatus == 200) {
            final data = customVerifyEmailData ??
                {
                  'user': {
                    'id': validUserId,
                    'phone': '+919876543210',
                    'email': 'yamini@example.com',
                    'full_name': 'Yamini Sharma',
                    'role': 'user',
                    'is_registration_complete': true,
                    'phone_confirmed_at': '2026-11-11T10:00:00Z',
                    'email_confirmed_at': '2026-11-11T10:01:00Z',
                    'created_at': '2026-11-11T09:59:00Z',
                  },
                  'tokens': {
                    'access_token': 'jwt_access_token_xyz',
                    'refresh_token': 'refresh_token_abc',
                    'token_type': 'Bearer',
                    'expires_in': 3600,
                  },
                };
            return http.Response(
              jsonEncode({
                'success': true,
                'data': data,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'INVALID_OTP', 'message': 'Invalid email OTP.'},
            }),
            verifyEmailStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/api/v1/auth/login/send-otp')) {
          if (sendLoginStatus == 200) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'message': 'Login OTP ready'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'NOT_FOUND', 'message': 'User not found.'},
            }),
            sendLoginStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/api/v1/auth/login/verify-otp')) {
          if (verifyLoginStatus == 200) {
            final data = customVerifyLoginData ??
                {
                  'user': {
                    'id': validUserId,
                    'phone': '+919876543210',
                    'email': 'yamini@example.com',
                    'full_name': 'Yamini Sharma',
                    'role': 'user',
                    'is_registration_complete': true,
                    'phone_confirmed_at': '2026-11-11T10:00:00Z',
                    'email_confirmed_at': '2026-11-11T10:01:00Z',
                    'created_at': '2026-11-11T09:59:00Z',
                  },
                  'tokens': {
                    'access_token': 'login_jwt_token',
                    'refresh_token': 'login_refresh_token',
                    'token_type': 'Bearer',
                    'expires_in': 3600,
                  },
                };
            return http.Response(
              jsonEncode({
                'success': true,
                'data': data,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'INVALID_OTP',
                'message': 'Invalid verification code.'
              },
            }),
            verifyLoginStatus,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/api/v1/auth/logout')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'message': 'Logged out successfully'}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      });
    }

    setUp(() {
      recordedRequests = [];
      recordedBodies = [];
    });

    test(
        '1. Valid registration response creates authenticated session and stores genuine tokens',
        () async {
      final mockHttp = createMockClient();
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final events = <AuthState>[];
      final sub = authService.onAuthStateChange.listen(events.add);

      // Step 1: Send registration OTP
      final sendResult = await authService.sendRegistrationMobileOtp(
        fullName: 'Yamini Sharma',
        mobileNumber: '9876543210',
        email: 'yamini@example.com',
      );
      expect(sendResult.isSuccess, isTrue);

      // Step 2: Verify mobile OTP
      final verifyMobileResult = await authService.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(verifyMobileResult.isSuccess, isTrue);

      // Step 3: Verify email OTP with valid response
      final verifyEmailResult = await authService.verifyEmailOtp(
        email: 'yamini@example.com',
        otp: '123456',
      );
      expect(verifyEmailResult.isSuccess, isTrue);
      expect(verifyEmailResult.user?.id, equals(validUserId));
      expect(authService.currentUser?.id, equals(validUserId));
      expect(authService.currentUser?.phoneConfirmedAt,
          equals('2026-11-11T10:00:00Z'));
      expect(authService.currentUser?.emailConfirmedAt,
          equals('2026-11-11T10:01:00Z'));
      expect(
          authService.currentUser?.createdAt, equals('2026-11-11T09:59:00Z'));

      expect(authService.currentSession?.accessToken,
          equals('jwt_access_token_xyz'));
      expect(authService.currentSession?.refreshToken,
          equals('refresh_token_abc'));
      expect(authService.isRegistrationComplete(), isTrue);

      // Token storage receives both genuine tokens
      expect(apiClient.accessToken, equals('jwt_access_token_xyz'));
      expect(apiClient.refreshToken, equals('refresh_token_abc'));
      expect(await apiClient.tokenStorage.getAccessToken(),
          equals('jwt_access_token_xyz'));
      expect(await apiClient.tokenStorage.getRefreshToken(),
          equals('refresh_token_abc'));

      // Event emitted
      expect(events.length, equals(1));
      expect(events.first.event, equals(AuthChangeEvent.signedIn));

      await sub.cancel();
    });

    test('2. Registration fails cleanly on invalid mobile OTP', () async {
      final mockHttp = createMockClient(verifyMobileStatus: 400);
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final result = await authService.verifyRegistrationMobileOtp(
        mobileNumber: '9876543210',
        otp: '000000',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid OTP code'));
    });

    test(
        '3. Valid login response creates authenticated session and stores genuine tokens',
        () async {
      final mockHttp = createMockClient();
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final events = <AuthState>[];
      final sub = authService.onAuthStateChange.listen(events.add);

      // Step 1: Send login OTP
      final sendResult =
          await authService.sendLoginOtp(mobileNumber: '9876543210');
      expect(sendResult.isSuccess, isTrue);

      // Step 2: Verify login OTP
      final verifyResult = await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(verifyResult.isSuccess, isTrue);
      expect(authService.currentUser?.id, equals(validUserId));
      expect(
          authService.currentSession?.accessToken, equals('login_jwt_token'));
      expect(authService.currentSession?.refreshToken,
          equals('login_refresh_token'));
      expect(apiClient.accessToken, equals('login_jwt_token'));
      expect(apiClient.refreshToken, equals('login_refresh_token'));
      expect(await apiClient.tokenStorage.getAccessToken(),
          equals('login_jwt_token'));
      expect(await apiClient.tokenStorage.getRefreshToken(),
          equals('login_refresh_token'));

      expect(events.length, equals(1));
      expect(events.first.event, equals(AuthChangeEvent.signedIn));

      await sub.cancel();
    });

    test(
        '4. Missing access token causes authentication failure without partial session',
        () async {
      final mockHttp = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': validUserId,
            'phone': '+919876543210',
            'is_registration_complete': true,
          },
          'tokens': {
            'refresh_token': 'refresh_token_only',
          },
        },
      );
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final events = <AuthState>[];
      final sub = authService.onAuthStateChange.listen(events.add);

      final result = await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('missing or empty access token'));
      expect(authService.currentUser, isNull);
      expect(authService.currentSession, isNull);
      expect(apiClient.accessToken, isNull);
      expect(events, isEmpty);

      await sub.cancel();
    });

    test(
        '5. Missing refresh token causes authentication failure without partial session',
        () async {
      final mockHttp = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': validUserId,
            'phone': '+919876543210',
            'is_registration_complete': true,
          },
          'tokens': {
            'access_token': 'access_token_only',
            'refresh_token': '',
          },
        },
      );
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final events = <AuthState>[];
      final sub = authService.onAuthStateChange.listen(events.add);

      final result = await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('missing or empty refresh token'));
      expect(authService.currentUser, isNull);
      expect(authService.currentSession, isNull);
      expect(apiClient.refreshToken, isNull);
      expect(events, isEmpty);

      await sub.cancel();
    });

    test('6. Missing or invalid user ID fails validation cleanly', () async {
      // 6a: Missing user ID
      final mockHttpMissing = createMockClient(
        customVerifyLoginData: {
          'user': {
            'phone': '+919876543210',
          },
          'tokens': {
            'access_token': 'access_token_valid',
            'refresh_token': 'refresh_token_valid',
          },
        },
      );
      final apiClientA = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: mockHttpMissing);
      final authServiceA = GoAuthService(apiClient: apiClientA);

      final resultA = await authServiceA.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(resultA.isSuccess, isFalse);
      expect(resultA.errorMessage, contains('missing or invalid user ID'));
      expect(authServiceA.currentUser, isNull);

      // 6b: Invalid user ID (not a UUID)
      final mockHttpInvalid = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': 'not-a-valid-uuid-12345',
            'phone': '+919876543210',
          },
          'tokens': {
            'access_token': 'access_token_valid',
            'refresh_token': 'refresh_token_valid',
          },
        },
      );
      final apiClientB = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: mockHttpInvalid);
      final authServiceB = GoAuthService(apiClient: apiClientB);

      final resultB = await authServiceB.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );
      expect(resultB.isSuccess, isFalse);
      expect(resultB.errorMessage, contains('missing or invalid user ID'));
      expect(authServiceB.currentUser, isNull);
      expect(authServiceB.currentSession, isNull);
    });

    test(
        '7. Missing confirmation timestamps are preserved as null without fabricating DateTime.now()',
        () async {
      final mockHttp = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': validUserId,
            'phone': '+919876543210',
            'email': 'yamini@example.com',
            'full_name': 'Yamini Sharma',
            'role': 'user',
            'is_registration_complete': true,
            'phone_confirmed_at': null,
            'email_confirmed_at': null,
            'created_at': '2026-11-11T09:59:00Z',
          },
          'tokens': {
            'access_token': 'login_jwt_token',
            'refresh_token': 'login_refresh_token',
          },
        },
      );
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final result = await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(authService.currentUser, isNotNull);
      // Confirmation timestamps MUST be null, not fabricated with DateTime.now()
      expect(authService.currentUser?.phoneConfirmedAt, isNull);
      expect(authService.currentUser?.emailConfirmedAt, isNull);
      expect(
          authService.currentUser?.createdAt, equals('2026-11-11T09:59:00Z'));
    });

    test('8. Registration incomplete is preserved exactly as returned by Go',
        () async {
      final mockHttp = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': validUserId,
            'phone': '+919876543210',
            'email': 'yamini@example.com',
            'full_name': 'Yamini Sharma',
            'role': 'user',
            'is_registration_complete': false,
            'phone_confirmed_at': '2026-11-11T10:00:00Z',
            'email_confirmed_at': '2026-11-11T10:01:00Z',
            'created_at': '2026-11-11T09:59:00Z',
          },
          'tokens': {
            'access_token': 'login_jwt_token',
            'refresh_token': 'login_refresh_token',
          },
        },
      );
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final result = await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(result.isSuccess, isTrue);
      // Registration complete status MUST be preserved as false
      expect(authService.isRegistrationComplete(), isFalse);
      expect(
          authService.isRegistrationComplete(authService.currentUser), isFalse);
    });

    test('9. No signed-in event is emitted on invalid response', () async {
      final mockHttp = createMockClient(
        customVerifyLoginData: {
          'user': {
            'id': 'not-a-uuid',
          },
          'tokens': {
            'access_token': 'jwt',
            'refresh_token': 'refresh',
          },
        },
      );
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      final events = <AuthState>[];
      final sub = authService.onAuthStateChange.listen(events.add);

      await authService.verifyLoginOtp(
        mobileNumber: '9876543210',
        otp: '123456',
      );

      expect(events, isEmpty);
      await sub.cancel();
    });

    test('10. Sign Out clears tokens and state', () async {
      final mockHttp = createMockClient();
      final apiClient =
          ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockHttp);
      final authService = GoAuthService(apiClient: apiClient);

      // Log in
      await authService.verifyLoginOtp(
          mobileNumber: '9876543210', otp: '123456');
      expect(authService.currentUser, isNotNull);

      // Sign out
      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(authService.currentSession, isNull);
      expect(apiClient.isAuthenticated, isFalse);
    });
  });
}

class TestMockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  TestMockClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
