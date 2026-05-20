import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/usage_limits.dart';

class LimitsProvider extends ChangeNotifier {
  UsageLimits? _limits;
  bool _isLoading = false;
  String? _error;

  UsageLimits? get limits => _limits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPro => _limits?.isPro ?? false;

  Future<void> loadLimits(String token, String baseUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/limits'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _limits = UsageLimits.fromJson(data);
        } else {
          _error = data['message'] ?? 'Ошибка загрузки лимитов';
        }
      } else {
        _error = 'Ошибка сервера: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refresh(String token, String baseUrl) {
    loadLimits(token, baseUrl);
  }
  
  void clear() {
    _limits = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
