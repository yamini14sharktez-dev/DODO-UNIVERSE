import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Token storage interface for persistent or in-memory session tokens.
abstract class ITokenStorage {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();
}

/// Default in-memory implementation of token storage.
class InMemoryTokenStorage implements ITokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
  }
}

/// Structured API exception thrown on error responses from the Go backend.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final dynamic details;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;
}

/// Centralized HTTP client for all Go backend API communications.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final ITokenStorage _tokenStorage;
  String? _accessToken;
  String? _refreshToken;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    ITokenStorage? tokenStorage,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? InMemoryTokenStorage();

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  ITokenStorage get tokenStorage => _tokenStorage;

  void setTokens({String? accessToken, String? refreshToken}) {
    if (accessToken != null) _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    if (_accessToken != null && _refreshToken != null) {
      _tokenStorage.saveTokens(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
      );
    }
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    _tokenStorage.clearTokens();
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      return Uri.parse('$fullUrl?$query');
    }
    return Uri.parse(fullUrl);
  }

  static const Duration requestTimeout = Duration(seconds: 10);

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final res = await _httpClient
          .get(_uri(path, queryParams), headers: _headers())
          .timeout(requestTimeout);
      return _processResponse(res);
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        code: 'TIMEOUT',
        message:
            'Connection timed out. Please ensure the Go backend is running on $baseUrl.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to authentication server. Please ensure the Go backend is running.',
        details: e.toString(),
      );
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _httpClient
          .post(
            _uri(path),
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _processResponse(res);
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        code: 'TIMEOUT',
        message:
            'Connection timed out. Please ensure the Go backend is running on $baseUrl.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to authentication server. Please ensure the Go backend is running.',
        details: e.toString(),
      );
    }
  }

  dynamic _processResponse(http.Response res) {
    dynamic decoded;
    try {
      if (res.body.isNotEmpty) {
        decoded = jsonDecode(res.body);
      }
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    String code = 'API_ERROR';
    String message = 'An error occurred (${res.statusCode})';
    dynamic details;

    if (decoded is Map && decoded['error'] is Map) {
      final errMap = decoded['error'] as Map;
      code = errMap['code']?.toString() ?? code;
      message = errMap['message']?.toString() ?? message;
      details = errMap['details'];
    } else if (decoded is Map && decoded['message'] != null) {
      message = decoded['message'].toString();
    }

    throw ApiException(
      statusCode: res.statusCode,
      code: code,
      message: message,
      details: details,
    );
  }
}
