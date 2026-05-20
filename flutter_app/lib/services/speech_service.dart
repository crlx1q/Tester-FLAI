import 'package:flutter/services.dart';

class SpeechService {
  static const MethodChannel _channel = MethodChannel('com.foodlens.speech');
  
  /// Запускает распознавание речи через встроенный сервис устройства
  static Future<String?> startListening() async {
    try {
      final String? result = await _channel.invokeMethod('startListening');
      return result;
    } on PlatformException catch (e) {
      print('Ошибка распознавания речи: ${e.message}');
      return null;
    }
  }
  
  /// Проверяет доступность распознавания речи
  static Future<bool> isAvailable() async {
    try {
      final bool? available = await _channel.invokeMethod('isAvailable');
      return available ?? false;
    } on PlatformException catch (e) {
      print('Ошибка проверки доступности: ${e.message}');
      return false;
    }
  }
}
