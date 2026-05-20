import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageHelper {
  /// Создает виджет Image из URL (поддерживает base64 и обычные URL)
  static Widget buildImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
    Widget? loadingWidget,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? const Icon(Icons.image_not_supported, size: 50);
    }

    try {
      // Проверяем если это base64 (с префиксом или без)
      if (imageUrl.startsWith('data:image') || _looksLikeBase64(imageUrl)) {
        return _buildBase64Image(
          imageUrl,
          fit: fit,
          width: width,
          height: height,
          errorWidget: errorWidget,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        );
      }

      // Обычный URL
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        alignment: Alignment.center, // Центрируем изображение
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return loadingWidget ??
              Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Ошибка загрузки изображения: $error');
          return errorWidget ?? const Icon(Icons.broken_image, size: 50);
        },
      );
    } catch (e) {
      print('❌ Ошибка обработки изображения: $e');
      return errorWidget ?? const Icon(Icons.error, size: 50);
    }
  }

  /// Создает виджет Image из base64 строки
  static Widget _buildBase64Image(
    String base64String, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    try {
      // Убираем префикс data:image/jpeg;base64, если есть
      String cleanBase64 = base64String;
      if (base64String.contains('base64,')) {
        cleanBase64 = base64String.split('base64,')[1];
      }

      // Декодируем base64
      final Uint8List bytes = base64Decode(cleanBase64);

      // Логируем только первый раз (для отладки)
      // print('✅ Декодировано base64 изображение: ${bytes.length} байт');

      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        alignment: Alignment.center, // Центрируем изображение
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true, // Убирает мерцание при скролле!
        errorBuilder: (context, error, stackTrace) {
          print('❌ Ошибка отображения base64: $error');
          return errorWidget ?? const Icon(Icons.broken_image, size: 50);
        },
      );
    } catch (e) {
      print('❌ Ошибка декодирования base64: $e');
      print('📝 Base64 начало: ${base64String.substring(0, 50)}...');
      return errorWidget ?? const Icon(Icons.error, size: 50);
    }
  }

  /// Проверяет является ли строка base64 изображением
  static bool isBase64Image(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return false;
    return imageUrl.startsWith('data:image') || _looksLikeBase64(imageUrl);
  }

  /// Проверяет похожа ли строка на base64 (без префикса)
  static bool _looksLikeBase64(String str) {
    // Base64 начинается с /9j/ (JPEG) или iVBORw (PNG) или R0lGOD (GIF)
    if (str.length < 20) return false;
    
    // Проверяем типичные начала base64 изображений
    if (str.startsWith('/9j/') || // JPEG
        str.startsWith('iVBORw') || // PNG
        str.startsWith('R0lGOD')) { // GIF
      return true;
    }
    
    // Проверяем что строка содержит только base64 символы
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
    final checkLength = str.length > 100 ? 100 : str.length;
    return base64Pattern.hasMatch(str.substring(0, checkLength));
  }

  /// Получает размер base64 изображения в KB
  static double getBase64SizeKB(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains('base64,')) {
        cleanBase64 = base64String.split('base64,')[1];
      }
      final bytes = base64Decode(cleanBase64);
      return bytes.length / 1024;
    } catch (e) {
      return 0;
    }
  }
}
