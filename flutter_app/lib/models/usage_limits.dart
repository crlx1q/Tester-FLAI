class UsageLimits {
  final String subscriptionType;
  final bool isPro;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int remainingDays;
  final UsageInfo photos;
  final UsageInfo messages;
  final UsageInfo recipes;
  final String date;

  UsageLimits({
    required this.subscriptionType,
    required this.isPro,
    this.startedAt,
    this.expiresAt,
    this.remainingDays = 0,
    required this.photos,
    required this.messages,
    required this.recipes,
    required this.date,
  });

  factory UsageLimits.fromJson(Map<String, dynamic> json) {
    return UsageLimits(
      subscriptionType: json['subscription']['type'],
      isPro: json['subscription']['isPro'],
      startedAt: json['subscription']['startedAt'] != null
          ? DateTime.parse(json['subscription']['startedAt'])
          : null,
      expiresAt: json['subscription']['expiresAt'] != null
          ? DateTime.parse(json['subscription']['expiresAt'])
          : null,
      remainingDays: json['subscription']['remainingDays'] ?? 0,
      photos: UsageInfo.fromJson(json['usage']['photos']),
      messages: UsageInfo.fromJson(json['usage']['messages']),
      recipes: UsageInfo.fromJson(json['usage']['recipes']),
      date: json['usage']['date'],
    );
  }
}

class UsageInfo {
  final int current;
  final int max;
  final int remaining;

  UsageInfo({
    required this.current,
    required this.max,
    required this.remaining,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      current: json['current'],
      max: json['max'],
      remaining: json['remaining'],
    );
  }

  double get percentage => (current / max * 100).clamp(0, 100);
  
  bool get isLimitReached => remaining <= 0;
}
