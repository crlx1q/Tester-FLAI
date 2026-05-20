import 'package:flutter/material.dart';
import '../utils/api_helper.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isPro => _user?.subscription == 'pro';
  int get currentStreak => _user?.displayStreak ?? 0;
  String get streakStatus => _user?.streakStatus ?? 'inactive';
  
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();
    
    final result = await ApiHelper.getProfile();
    
    if (result['success']) {
      _user = UserModel.fromJson(result['user']);
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final result = await ApiHelper.updateProfile(data);
    
    if (result['success']) {
      await loadProfile();
      return true;
    }
    
    return false;
  }
  
  Future<Map<String, dynamic>> completeOnboarding(Map<String, dynamic> data) async {
    // Используем AI персонализацию
    final result = await ApiHelper.completeOnboardingWithAI(data);
    
    if (result['success']) {
      await loadProfile();
      return {
        'success': true,
        'aiPlan': result['aiPlan'], // Возвращаем AI план для показа пользователю
      };
    }
    
    return {'success': false, 'message': result['message']};
  }
  
  Future<void> recordDailyVisit() async {
    final result = await ApiHelper.recordDailyVisit();
    
    if (result['success']) {
      await loadProfile();
    }
  }
  
  void clear() {
    _user = null;
    notifyListeners();
  }
}
