import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class AdminApiClient {
  static final AdminApiClient _instance = AdminApiClient._internal();
  factory AdminApiClient() => _instance;
  AdminApiClient._internal();

  String baseUrl = 'http://localhost:8080/api/v1/admin';
  String? accessToken;
  String? refreshToken;
  AdminUser? currentAdmin;

  void setTokens(String access, String refresh) {
    accessToken = access;
    refreshToken = refresh;
  }

  void clearTokens() {
    accessToken = null;
    refreshToken = null;
    currentAdmin = null;
  }

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null) {
      map['Authorization'] = 'Bearer $accessToken';
    }
    return map;
  }

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _handleResponse(res);
  }

  Future<dynamic> post(String path, dynamic body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<dynamic> put(String path, dynamic body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<dynamic> patch(String path, dynamic body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    String msg = 'Request failed (${res.statusCode})';
    try {
      final err = jsonDecode(res.body);
      msg = err['message'] ?? err['error'] ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  // Auth
  Future<AdminUser> login(String identifier, String password) async {
    final data = await post('/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    accessToken = data['tokens']['access_token'];
    refreshToken = data['tokens']['refresh_token'];
    currentAdmin = AdminUser.fromJson(data['admin']);
    return currentAdmin!;
  }

  Future<void> logout() async {
    if (refreshToken != null) {
      try {
        await post('/auth/logout', {'refresh_token': refreshToken});
      } catch (_) {}
    }
    clearTokens();
  }

  // Dashboard
  Future<DashboardMetrics> getDashboardMetrics() async {
    final data = await get('/dashboard/metrics');
    return DashboardMetrics.fromJson(data);
  }

  // People
  Future<List<Person>> getPeople({String search = '', int limit = 20, int offset = 0}) async {
    final data = await get('/people?search=${Uri.encodeComponent(search)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Person.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getPersonDetails(String id) async {
    final data = await get('/people/$id');
    return data;
  }

  Future<void> setPersonStatus(String id, bool suspended) async {
    await patch('/people/$id/status', {'suspended': suspended});
  }

  // Vendor Applications
  Future<List<VendorApplicationItem>> getVendorApplications({String status = '', int limit = 20, int offset = 0}) async {
    final data = await get('/vendor-applications?status=${Uri.encodeComponent(status)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => VendorApplicationItem.fromJson(e)).toList();
  }

  Future<void> approveVendorApplication(String id) async {
    await post('/vendor-applications/$id/approve', {});
  }

  Future<void> rejectVendorApplication(String id, String reason) async {
    await post('/vendor-applications/$id/reject', {'reason': reason});
  }

  Future<void> requestInfoVendorApplication(String id, String notes) async {
    await post('/vendor-applications/$id/request-info', {'notes': notes});
  }

  // Categories
  Future<List<ServiceCategoryItem>> getCategories() async {
    final data = await get('/categories');
    final list = data as List<dynamic>? ?? [];
    return list.map((e) => ServiceCategoryItem.fromJson(e)).toList();
  }

  Future<void> createCategory(Map<String, dynamic> body) async {
    await post('/categories', body);
  }

  Future<void> updateCategory(String id, Map<String, dynamic> body) async {
    await put('/categories/$id', body);
  }

  Future<void> deleteCategory(String id) async {
    await delete('/categories/$id');
  }

  // Form Builder
  Future<Map<String, dynamic>> getFormDefinition(String categoryId) async {
    return await get('/forms/$categoryId');
  }

  Future<void> saveFormDefinition(String categoryId, Map<String, dynamic> body) async {
    await post('/forms/$categoryId', body);
  }

  // Listings
  Future<List<ProductListingItem>> getListings({String status = '', int limit = 20, int offset = 0}) async {
    final data = await get('/listings?status=${Uri.encodeComponent(status)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => ProductListingItem.fromJson(e)).toList();
  }

  Future<void> updateListingApproval(String id, String approval) async {
    await patch('/listings/$id/approval', {'approval': approval});
  }

  Future<void> updateListingStatus(String id, bool active) async {
    await patch('/listings/$id/status', {'active': active});
  }

  // Orders
  Future<List<AdminOrderItem>> getOrders({String status = '', String search = '', int limit = 20, int offset = 0}) async {
    final data = await get('/orders?status=${Uri.encodeComponent(status)}&search=${Uri.encodeComponent(search)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => AdminOrderItem.fromJson(e)).toList();
  }

  Future<void> resolveOrderDispute(String id, String resolution) async {
    await patch('/orders/$id/dispute', {'resolution': resolution});
  }

  // Requests
  Future<List<QuotationRequestItem>> getQuotationRequests({String status = '', int limit = 20, int offset = 0}) async {
    final data = await get('/quotes/requests?status=${Uri.encodeComponent(status)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => QuotationRequestItem.fromJson(e)).toList();
  }

  // Payments & Commission
  Future<List<PaymentRecordItem>> getPayments({String type = '', String status = '', int limit = 20, int offset = 0}) async {
    final data = await get('/finance/transactions?type=${Uri.encodeComponent(type)}&status=${Uri.encodeComponent(status)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => PaymentRecordItem.fromJson(e)).toList();
  }

  Future<List<CommissionRuleItem>> getCommissionRules() async {
    final data = await get('/finance/commissions');
    final list = data as List<dynamic>? ?? [];
    return list.map((e) => CommissionRuleItem.fromJson(e)).toList();
  }

  Future<void> setCommissionRule(Map<String, dynamic> body) async {
    await put('/finance/commissions', body);
  }

  // Admins
  Future<List<AdminUser>> getAdmins() async {
    final data = await get('/admins');
    final list = data as List<dynamic>? ?? [];
    return list.map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<void> createAdmin(Map<String, dynamic> body) async {
    await post('/admins', body);
  }

  Future<void> updateAdmin(String id, Map<String, dynamic> body) async {
    await patch('/admins/$id', body);
  }

  // Audit Logs
  Future<List<AuditLogItem>> getAuditLogs({String entityType = '', String action = '', int limit = 20, int offset = 0}) async {
    final data = await get('/audit-logs?entity_type=${Uri.encodeComponent(entityType)}&action=${Uri.encodeComponent(action)}&limit=$limit&offset=$offset');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => AuditLogItem.fromJson(e)).toList();
  }

  // Settings
  Future<Map<String, dynamic>> getSettings() async {
    return await get('/settings');
  }

  Future<void> updateSetting(String key, dynamic value) async {
    await put('/settings', {'key': key, 'value': value});
  }
}
