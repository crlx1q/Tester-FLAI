import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/api_helper.dart';

class ApkInstallerService {
  static Future<void> downloadAndInstallApk({
    required Function(double) onProgress,
    required Function(String) onError,
    required Function() onComplete,
  }) async {
    try {
      // Запрашиваем разрешения для Android 13+
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            // Для Android 13+ разрешение storage не требуется для Downloads
            print('Storage permission not granted, but continuing...');
          }
        }
      }

      // Получаем директорию Downloads
      Directory? dir;
      if (Platform.isAndroid) {
        // Используем /storage/emulated/0/Download для Android
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          // Fallback на getExternalStorageDirectory
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getDownloadsDirectory();
      }
      
      if (dir == null) {
        onError('Не удалось получить доступ к хранилищу');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final apkPath = '${dir.path}/FoodLensAI_$timestamp.apk';
      final apkFile = File(apkPath);

      print('Downloading APK to: $apkPath');

      // Загружаем APK
      final dio = Dio();
      final downloadUrl = '${ApiHelper.baseUrl}/admin/download-apk';

      await dio.download(
        downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      // Проверяем что файл загружен
      if (!await apkFile.exists()) {
        onError('Файл не был загружен');
        return;
      }

      final fileSize = await apkFile.length();
      print('APK downloaded successfully. Size: ${fileSize} bytes');

      if (fileSize < 1000) {
        onError('Загруженный файл слишком мал. Возможно, это не APK файл.');
        return;
      }

      onComplete();

      // Небольшая задержка перед открытием
      await Future.delayed(const Duration(milliseconds: 500));

      // Открываем APK для установки с правильным MIME type
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      
      print('OpenFilex result: ${result.type} - ${result.message}');
      
      if (result.type != ResultType.done) {
        onError('Не удалось открыть файл для установки: ${result.message}');
      }
    } catch (e) {
      print('Error in downloadAndInstallApk: $e');
      onError('Ошибка загрузки: $e');
    }
  }
}
