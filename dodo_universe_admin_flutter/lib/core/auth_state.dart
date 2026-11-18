import 'package:flutter/material.dart';
import 'api_client.dart';
import 'models.dart';

class AdminAuthState extends ChangeNotifier {
  final AdminApiClient _api = AdminApiClient();
  bool _isLoading = false;
  String? _errorMessage;

  AdminUser? get currentAdmin => _api.currentAdmin;
  bool get isAuthenticated => _api.currentAdmin != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.login(identifier, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    notifyListeners();
  }
}
