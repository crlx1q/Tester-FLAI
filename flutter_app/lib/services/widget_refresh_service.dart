import 'package:flutter/services.dart';

class WidgetRefreshService {
  static const MethodChannel _channel = MethodChannel('com.foodlens.widget');

  static Future<void> refreshWidgets() async {
    try {
      await _channel.invokeMethod('refreshWidgets');
    } catch (e) {
      print('Failed to refresh widgets: $e');
    }
  }
}
