import 'food_model.dart';

class DailySummaryModel {
  final List<FoodModel> foods;
  final int totalCalories;
  final int targetCalories;
  final MacrosModel consumedMacros;
  final MacrosModel targetMacros;

  DailySummaryModel({
    required this.foods,
    required this.totalCalories,
    required this.targetCalories,
    required this.consumedMacros,
    required this.targetMacros,
  });

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    return DailySummaryModel(
      foods: (json['foods'] as List?)
              ?.map((food) => FoodModel.fromJson(food))
              .toList() ??
          [],
      totalCalories: json['totalCalories'] ?? 0,
      targetCalories: json['targetCalories'] ?? 2000,
      consumedMacros: MacrosModel.fromJson(json['consumedMacros'] ?? {}),
      targetMacros: MacrosModel.fromJson(json['targetMacros'] ?? {}),
    );
  }
}

class MacrosModel {
  final int protein;
  final int carbs;
  final int fat;

  MacrosModel({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MacrosModel.fromJson(Map<String, dynamic> json) {
    return MacrosModel(
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}
