import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update_model.dart';
import '../utils/api_helper.dart';

class UpdateProvider with ChangeNotifier {
  AppUpdateInfo? _updateInfo;
  bool _hasSeenUpdate = false;
  bool _isChecking = false;

  static const String _lastCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 24);

  AppUpdateInfo? get updateInfo => _updateInfo;
  bool get hasSeenUpdate => _hasSeenUpdate;
  bool get isChecking => _isChecking;
  bool get hasUnreadUpdate => _updateInfo?.needsUpdate == true && !_hasSeenUpdate;

  Future<void> checkForUpdates(String currentVersion) async {
    if (_isChecking) return;
    
    _isChecking = true;
    notifyListeners();

    try {
      final result = await ApiHelper.checkVersion(currentVersion);
      
      if (result['success']) {
        _updateInfo = AppUpdateInfo.fromJson(result);
        
        // Если обновление доступно, сбрасываем флаг просмотра
        if (_updateInfo!.needsUpdate) {
          _hasSeenUpdate = false;
        }
      }
      
      // Сохраняем время последней проверки
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error checking for updates: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Проверяет обновления только если прошло >= 24 часа с последней проверки
  Future<void> checkForUpdatesIfNeeded(String currentVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey);
      
      if (lastCheck == null) {
        // Первая проверка
        await checkForUpdates(currentVersion);
        return;
      }
      
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final elapsed = DateTime.now().difference(lastCheckTime);
      
      if (elapsed >= _checkInterval) {
        await checkForUpdates(currentVersion);
      }
    } catch (e) {
      print('Error checking update schedule: $e');
    }
  }

  void markUpdateAsSeen() {
    _hasSeenUpdate = true;
    notifyListeners();
  }

  void clearUpdate() {
    _updateInfo = null;
    _hasSeenUpdate = false;
    notifyListeners();
  }

  /// Удаляет старые APK файлы из Downloads после установки
  static Future<void> cleanupOldApks() async {
    try {
      if (!Platform.isAndroid) return;
      
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) return;
      
      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.apk') && file.path.contains('foodlens')) {
          try {
            await file.delete();
            print('Deleted old APK: ${file.path}');
          } catch (e) {
            print('Failed to delete APK: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('APK cleanup error: $e');
    }
  }
}
