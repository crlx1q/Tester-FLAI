class FoodModel {
  final String id;
  final String userId;
  final String name;
  final String? imageUrl;
  final int calories;
  final Macros macros;
  final int healthScore;
  final DateTime timestamp;
  final String mealType;
  
  FoodModel({
    required this.id,
    required this.userId,
    required this.name,
    this.imageUrl,
    required this.calories,
    required this.macros,
    this.healthScore = 50,
    required this.timestamp,
    required this.mealType,
  });
  
  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Неизвестное блюдо',
      imageUrl: json['imageUrl'],
      calories: (json['calories'] ?? 0).toInt(),
      macros: Macros.fromJson(json['macros'] ?? {}),
      healthScore: json.containsKey('healthScore') ? (json['healthScore'] ?? 0).toInt() : 50,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']).toLocal() 
          : DateTime.now(),
      mealType: json['mealType'] ?? 'Перекус',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'name': name,
      'imageUrl': imageUrl,
      'calories': calories,
      'macros': macros.toJson(),
      'healthScore': healthScore,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'mealType': mealType,
    };
  }
}

class Macros {
  final double carbs;
  final double protein;
  final double fat;
  
  Macros({
    required this.carbs,
    required this.protein,
    required this.fat,
  });
  
  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
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

class DailySummary {
  final int totalCalories;
  final int targetCalories;
  final int remainingCalories;
  final Macros consumedMacros;
  final Macros targetMacros;
  final List<FoodModel> foods;
  
  DailySummary({
    required this.totalCalories,
    required this.targetCalories,
    required this.remainingCalories,
    required this.consumedMacros,
    required this.targetMacros,
    required this.foods,
  });
  
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      totalCalories: (json['totalCalories'] ?? 0).toInt(),
      targetCalories: (json['targetCalories'] ?? 2000).toInt(),
      remainingCalories: (json['remainingCalories'] ?? 2000).toInt(),
      consumedMacros: Macros.fromJson(json['consumedMacros'] ?? {}),
      targetMacros: Macros.fromJson(json['targetMacros'] ?? {}),
      foods: (json['foods'] as List?)?.map((f) => FoodModel.fromJson(f)).toList() ?? [],
    );
  }
}
