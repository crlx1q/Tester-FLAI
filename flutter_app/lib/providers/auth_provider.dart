import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_helper.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _userId;
  String? _email;
  String? _errorMessage;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get email => _email;
  String? get errorMessage => _errorMessage;
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // Получение токена из SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  AuthProvider() {
    _checkAuth();
  }
  
  Future<void> _checkAuth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null) {
      // Проверяем валидность токена через API
      final result = await ApiHelper.getProfile();
      if (result['success']) {
        _isAuthenticated = true;
        _userId = result['user']['_id'];
        _email = result['user']['email'];
      } else {
        _isAuthenticated = false;
        await prefs.remove('auth_token');
        
        // Если ошибка подключения к серверу - показываем уведомление
        if (result['message'] == 'Ошибка подключения к серверу') {
          _errorMessage = 'Сервер не отвечает. Проверьте подключение к интернету';
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? username,
  }) async {
    final result = await ApiHelper.register(
      email: email,
      password: password,
      name: name,
      username: username,
    );
    
    if (result['success']) {
      // Автоматически входим после регистрации
      return await login(email: email, password: password);
    }
    
    return result;
  }
  
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await ApiHelper.login(
      email: email,
      password: password,
    );
    
    if (result['success']) {
      _isAuthenticated = true;
      _userId = result['user']['_id'];
      _email = result['user']['email'];
      notifyListeners();
    }
    
    return result;
  }
  
  Future<void> logout() async {
    await ApiHelper.logout();
    _isAuthenticated = false;
    _userId = null;
    _email = null;
    notifyListeners();
  }
}
