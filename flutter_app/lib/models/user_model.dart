class UserModel {
  final String id;
  final String email;
  final String name;
  final String? username;
  final String? avatar;
  final int? age;
  final int? height;
  final double? weight;
  final String? gender;
  final String? goal;
  final String? goalDescription;
  final String? activityLevel;
  final List<String> allergies;
  final String subscription;
  final DateTime? subscriptionExpiresAt;
  final int subscriptionRemainingDays;
  final int streak;
  final int maxStreak;
  final DateTime? lastVisit;
  final String streakStatus;
  final int displayStreak;
  final bool onboardingCompleted;
  final int dailyCalories;
  final MacroGoals? macros;
  final double? targetWeight;
  final int? waterTarget;
  
  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.avatar,
    this.age,
    this.height,
    this.weight,
    this.gender,
    this.goal,
    this.goalDescription,
    this.activityLevel,
    this.allergies = const [],
    this.subscription = 'free',
    this.subscriptionExpiresAt,
    this.subscriptionRemainingDays = 0,
    this.streak = 0,
    this.maxStreak = 0,
    this.lastVisit,
    this.streakStatus = 'inactive',
    this.displayStreak = 0,
    this.onboardingCompleted = false,
    this.dailyCalories = 2000,
    this.macros,
    this.targetWeight,
    this.waterTarget,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'],
      email: json['email'],
      name: json['name'],
      username: json['username'],
      avatar: json['avatarUrl'] ?? json['avatar'], // Используем виртуальное поле с base64!
      age: json['age'],
      height: json['height'],
      weight: json['weight']?.toDouble(),
      gender: json['gender'],
      goal: json['goal'],
      goalDescription: json['goalDescription'],
      activityLevel: json['activityLevel'],
      allergies: List<String>.from(json['allergies'] ?? []),
      subscription: json['subscriptionType'] ?? json['subscription'] ?? 'free',
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null 
          ? DateTime.parse(json['subscriptionExpiresAt']) 
          : null,
      subscriptionRemainingDays: json['subscriptionRemainingDays'] ?? 0,
      streak: json['streak'] ?? 0,
      maxStreak: json['maxStreak'] ?? 0,
      lastVisit: json['lastVisit'] != null ? DateTime.parse(json['lastVisit']) : null,
      streakStatus: json['streakStatus'] ?? 'inactive',
      displayStreak: json['displayStreak'] ?? 0,
      onboardingCompleted: json['onboardingCompleted'] ?? false,
      dailyCalories: json['dailyCalories'] ?? 2000,
      macros: json['macros'] != null ? MacroGoals.fromJson(json['macros']) : null,
      targetWeight: json['targetWeight']?.toDouble(),
      waterTarget: json['waterTarget'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'name': name,
      'username': username,
      'avatar': avatar,
      'age': age,
      'height': height,
      'weight': weight,
      'gender': gender,
      'goal': goal,
      'goalDescription': goalDescription,
      'activityLevel': activityLevel,
      'allergies': allergies,
      'subscription': subscription,
      'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
      'subscriptionRemainingDays': subscriptionRemainingDays,
      'streak': streak,
      'maxStreak': maxStreak,
      'lastVisit': lastVisit?.toIso8601String(),
      'streakStatus': streakStatus,
      'displayStreak': displayStreak,
      'onboardingCompleted': onboardingCompleted,
      'dailyCalories': dailyCalories,
      'macros': macros?.toJson(),
      'targetWeight': targetWeight,
      'waterTarget': waterTarget,
    };
  }
}

class MacroGoals {
  final double carbs;
  final double protein;
  final double fat;
  
  MacroGoals({
    required this.carbs,
    required this.protein,
    required this.fat,
  });
  
  factory MacroGoals.fromJson(Map<String, dynamic> json) {
    return MacroGoals(
      carbs: (json['carbs'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    };
  }
}
