import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_helper.dart';
import '../../utils/image_helper.dart';
import '../../utils/theme.dart';
import '../../models/recipe_model.dart';
import '../../widgets/pro_badge.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<RecipeModel> _recipes = [];
  bool _isLoading = true;
  String? _selectedGoal;
  final List<String> _selectedAllergies = [];
  List<String> _favoriteRecipeIds = [];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);

    // Загружаем избранные рецепты
    final favoritesResult = await ApiHelper.getFavoriteRecipes();
    if (favoritesResult['success']) {
      _favoriteRecipeIds = (favoritesResult['recipes'] as List)
          .map((r) => r['_id']?.toString() ?? r['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }

    // Загружаем рецепты
    final result = await ApiHelper.getRecipes(
      goal: _selectedGoal,
      allergies: _selectedAllergies,
    );

    if (result['success']) {
      setState(() {
        _recipes = (result['recipes'] as List)
            .map((r) {
              final recipe = RecipeModel.fromJson(r);
              // Проверяем есть ли в избранном
              final isFavorite = _favoriteRecipeIds.contains(recipe.id);
              return RecipeModel(
                id: recipe.id,
                userId: recipe.userId,
                name: recipe.name,
                imageUrl: recipe.imageUrl,
                calories: recipe.calories,
                macros: recipe.macros,
                prepTime: recipe.prepTime,
                difficulty: recipe.difficulty,
                servings: recipe.servings,
                cookTime: recipe.cookTime,
                ingredients: recipe.ingredients,
                instructions: recipe.instructions,
                isFavorite: isFavorite,
                createdAt: recipe.createdAt,
                author: recipe.author,
              );
            })
            .toList();
      });
    }

    setState(() => _isLoading = false);
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Future<void> _navigateToAddRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecipeScreen(),
      ),
    );

    if (result == true) {
      _loadRecipes();
    }
  }

  Future<void> _navigateToRecipeDetail(RecipeModel recipe) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );

    if (result == true) {
      _loadRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            onPressed: _showFilters,
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _navigateToAddRecipe,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecipes,
              child: _recipes.isEmpty
                  ? const Center(
                      child: Text('Рецепты не найдены'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _recipes.length,
                      itemBuilder: (context, index) {
                        return _buildRecipeCard(_recipes[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _navigateToRecipeDetail(recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay badge
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: recipe.imageUrl != null
                      ? ImageHelper.buildImage(
                          recipe.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Icon(Icons.restaurant_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          loadingWidget: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange.withOpacity(0.5)),
                          ),
                        )
                      : Icon(Icons.restaurant_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ),
                // Calorie badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${recipe.calories} ккал',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Info row
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.prepTime} мин',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 14),
                      Icon(Icons.signal_cellular_alt_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        recipe.difficulty,
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Macros
                  Row(
                    children: [
                      _buildMacroChip('Б ${recipe.macros.protein.toStringAsFixed(0)}г', const Color(0xFFEF5350)),
                      const SizedBox(width: 6),
                      _buildMacroChip('Ж ${recipe.macros.fat.toStringAsFixed(0)}г', const Color(0xFFFFA726)),
                      const SizedBox(width: 6),
                      _buildMacroChip('У ${recipe.macros.carbs.toStringAsFixed(0)}г', const Color(0xFF42A5F5)),
                    ],
                  ),

                  // Автор
                  if (recipe.author != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          recipe.author!.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (recipe.author!.isVerified)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 8,
                            ),
                          ),
                        if (recipe.author!.isPro)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: const ProBadge(tiny: true),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFiltersSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Фильтры',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Goal filter
              const Text(
                'Цель питания',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip(
                    'Снижение веса',
                    _selectedGoal == 'lose_weight',
                    () {
                      setModalState(() {
                        _selectedGoal = _selectedGoal == 'lose_weight'
                            ? null
                            : 'lose_weight';
                      });
                    },
                  ),
                  _buildFilterChip(
                    'Набор массы',
                    _selectedGoal == 'gain_muscle',
                    () {
                      setModalState(() {
                        _selectedGoal = _selectedGoal == 'gain_muscle'
                            ? null
                            : 'gain_muscle';
                      });
                    },
                  ),
                  _buildFilterChip(
                    'Поддержание',
                    _selectedGoal == 'maintain_weight',
                    () {
                      setModalState(() {
                        _selectedGoal = _selectedGoal == 'maintain_weight'
                            ? null
                            : 'maintain_weight';
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Allergies filter
              const Text(
                'Исключить аллергены',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip(
                    'Глютен',
                    _selectedAllergies.contains('gluten'),
                    () {
                      setModalState(() {
                        if (_selectedAllergies.contains('gluten')) {
                          _selectedAllergies.remove('gluten');
                        } else {
                          _selectedAllergies.add('gluten');
                        }
                      });
                    },
                  ),
                  _buildFilterChip(
                    'Лактоза',
                    _selectedAllergies.contains('lactose'),
                    () {
                      setModalState(() {
                        if (_selectedAllergies.contains('lactose')) {
                          _selectedAllergies.remove('lactose');
                        } else {
                          _selectedAllergies.add('lactose');
                        }
                      });
                    },
                  ),
                  _buildFilterChip(
                    'Орехи',
                    _selectedAllergies.contains('nuts'),
                    () {
                      setModalState(() {
                        if (_selectedAllergies.contains('nuts')) {
                          _selectedAllergies.remove('nuts');
                        } else {
                          _selectedAllergies.add('nuts');
                        }
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Apply button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadRecipes();
                  },
                  child: const Text('Применить фильтры'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryOrange,
    );
  }
}

