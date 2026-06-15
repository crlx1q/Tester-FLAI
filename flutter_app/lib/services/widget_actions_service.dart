import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class WidgetActionsService {
  static StreamSubscription? _linkSubscription;
  static Function(String action)? _onAction;
  static AppLinks? _appLinks;

  static void initialize({required Function(String action) onAction}) {
    _onAction = onAction;
    _initDeepLinks();
  }

  static Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();
      
      // Handle initial link (app was cold-started via deep link)
      final initialLink = await _appLinks!.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink.toString());
      }

      // Handle links while app is running
      _linkSubscription = _appLinks!.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleLink(uri.toString());
        }
      }, onError: (err) {
        debugPrint('Link stream error: $err');
      });
    } catch (e) {
      debugPrint('Deep links init error: $e');
    }
  }

  static void _handleLink(String link) {
    try {
      final uri = Uri.parse(link);
      
      if (uri.scheme == 'foodlens') {
        switch (uri.host) {
          case 'camera':
            _onAction?.call('camera');
            break;
          default:
            _onAction?.call('open');
        }
      }
    } catch (e) {
      debugPrint('Handle link error: $e');
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
