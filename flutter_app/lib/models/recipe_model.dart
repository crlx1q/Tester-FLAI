class RecipeModel {
  final String id;
  final String userId;
  final String name;
  final String? imageUrl;
  final int calories;
  final Macros macros;
  final int prepTime;
  final String difficulty;
  final int servings;
  final String? cookTime;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final bool isFavorite;
  final DateTime createdAt;
  final RecipeAuthor? author;

  RecipeModel({
    required this.id,
    required this.userId,
    required this.name,
    this.imageUrl,
    required this.calories,
    required this.macros,
    required this.prepTime,
    required this.difficulty,
    this.servings = 1,
    this.cookTime,
    required this.ingredients,
    required this.instructions,
    this.isFavorite = false,
    required this.createdAt,
    this.author,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Без названия',
      imageUrl: json['imageUrl'],
      calories: (json['calories'] ?? 0).toInt(),
      macros: Macros.fromJson(json['macros'] ?? {}),
      prepTime: (json['prepTime'] ?? 0).toInt(),
      difficulty: json['difficulty'] ?? 'Легко',
      servings: (json['servings'] ?? 1).toInt(),
      cookTime: json['cookTime'],
      ingredients: (json['ingredients'] as List?)
              ?.map((i) => Ingredient.fromJson(i))
              .toList() ??
          [],
      instructions: (json['instructions'] as List?)
              ?.map((i) => i.toString())
              .toList() ??
          [],
      isFavorite: json['isFavorite'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      author: json['author'] != null
          ? RecipeAuthor.fromJson(json['author'])
          : null,
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
      'prepTime': prepTime,
      'difficulty': difficulty,
      'servings': servings,
      'cookTime': cookTime,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'author': author?.toJson(),
    };
  }
}

class Macros {
  final double protein;
  final double fat;
  final double carbs;

  Macros({
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
      protein: (json['protein'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }
}

class Ingredient {
  final String name;
  final String amount;
  final int? calories;
  final String? unit;

  Ingredient({
    required this.name,
    required this.amount,
    this.calories,
    this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      calories: json['calories'] != null ? (json['calories'] as num).toInt() : null,
      unit: json['unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'calories': calories,
      'unit': unit,
    };
  }
}

class RecipeAuthor {
  final String name;
  final String? avatar;
  final bool isVerified;
  final bool isPro;

  RecipeAuthor({
    required this.name,
    this.avatar,
    this.isVerified = false,
    this.isPro = false,
  });

  factory RecipeAuthor.fromJson(Map<String, dynamic> json) {
    return RecipeAuthor(
      name: json['name'] ?? 'Пользователь',
      avatar: json['avatarUrl'] ?? json['avatar'],
      isVerified: json['isVerified'] ?? false,
      isPro: json['isPro'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatar': avatar,
      'isVerified': isVerified,
      'isPro': isPro,
    };
  }
}
