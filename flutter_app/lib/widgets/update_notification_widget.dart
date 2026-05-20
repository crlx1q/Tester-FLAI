import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/update_provider.dart';
import '../services/apk_installer_service.dart';

class UpdateNotificationWidget extends StatefulWidget {
  const UpdateNotificationWidget({super.key});

  @override
  State<UpdateNotificationWidget> createState() => _UpdateNotificationWidgetState();
}

class _UpdateNotificationWidgetState extends State<UpdateNotificationWidget> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  void _downloadUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    await ApkInstallerService.downloadAndInstallApk(
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Загрузка завершена! Установите обновление'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Не очищаем информацию об обновлении сразу
          // Пользователь может захотеть переустановить
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, updateProvider, _) {
        final updateInfo = updateProvider.updateInfo;
        
        if (updateInfo == null || !updateInfo.needsUpdate) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.system_update,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Доступно обновление',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Версия ${updateInfo.currentVersion}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (updateInfo.updateDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  updateInfo.updateDescription,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_isDownloading) ...[
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Загрузка: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _downloadUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Скачать обновление',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
