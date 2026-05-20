import 'food_model.dart';

class FavoriteFoodModel {
  final String id;
  final String name;
  final int calories;
  final Macros macros;
  final DateTime addedAt;
  
  FavoriteFoodModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.macros,
    required this.addedAt,
  });
  
  factory FavoriteFoodModel.fromJson(Map<String, dynamic> json) {
    return FavoriteFoodModel(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      calories: json['calories'],
      macros: Macros.fromJson(json['macros']),
      addedAt: DateTime.parse(json['addedAt']).toLocal(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'calories': calories,
      'macros': macros.toJson(),
      'addedAt': addedAt.toUtc().toIso8601String(),
    };
  }
}
