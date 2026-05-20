class AppUpdateInfo {
  final bool needsUpdate;
  final String currentVersion;
  final String updateDescription;
  final String? downloadUrl;

  AppUpdateInfo({
    required this.needsUpdate,
    required this.currentVersion,
    required this.updateDescription,
    this.downloadUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      needsUpdate: json['needsUpdate'] ?? false,
      currentVersion: json['currentVersion'] ?? '1.0.0',
      updateDescription: json['updateDescription'] ?? '',
      downloadUrl: json['downloadUrl'],
    );
  }
}
