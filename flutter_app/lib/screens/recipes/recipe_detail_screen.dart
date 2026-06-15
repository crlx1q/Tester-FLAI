import 'package:flutter/material.dart';
import '../../models/recipe_model.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';
import '../../utils/image_helper.dart';
import '../../widgets/pro_badge.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeModel recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.recipe.isFavorite;
  }

  Future<void> _toggleFavorite() async {
    final result = await ApiHelper.toggleRecipeFavorite(widget.recipe.id, _isFavorite);
    
    if (result['success']) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar с изображением
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.recipe.imageUrl != null
                      ? ImageHelper.buildImage(
                          widget.recipe.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.restaurant, size: 80),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant, size: 80),
                        ),
                  // Градиент для читаемости текста
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название
                    Text(
                      widget.recipe.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Инфо строка
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.access_time,
                          '${widget.recipe.prepTime} мин',
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.restaurant,
                          widget.recipe.difficulty,
                          Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.people,
                          '${widget.recipe.servings} порц',
                          Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Калории и БЖУ
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFFFF4E6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutritionInfo(
                            '${widget.recipe.calories}',
                            'ккал',
                            Icons.local_fire_department,
                            const Color(0xFFFF6B35),
                          ),
                          _buildNutritionInfo(
                            '${widget.recipe.macros.protein.toStringAsFixed(1)}г',
                            'Белки',
                            Icons.fitness_center,
                            const Color(0xFFEF5350),
                          ),
                          _buildNutritionInfo(
                            '${widget.recipe.macros.fat.toStringAsFixed(1)}г',
                            'Жиры',
                            Icons.cookie,
                            const Color(0xFFFFCA28),
                          ),
                          _buildNutritionInfo(
                            '${widget.recipe.macros.carbs.toStringAsFixed(1)}г',
                            'Углев',
                            Icons.bakery_dining,
                            const Color(0xFF66BB6A),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Автор рецепта
                    if (widget.recipe.author != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF374151)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: widget.recipe.author!.avatar != null
                                  ? ImageHelper.buildImage(
                                      widget.recipe.author!.avatar,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      cacheWidth: 80,
                                      cacheHeight: 80,
                                      errorWidget: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryOrange.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryOrange.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.recipe.author!.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (widget.recipe.author!.isVerified)
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      if (widget.recipe.author!.isPro)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          child: const ProBadge(tiny: true),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    'Автор рецепта',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Избранное
                    if (widget.recipe.ingredients.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Избранное',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _isFavorite
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed: _toggleFavorite,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Готовить',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Ингредиенты
                    const Text(
                      'Ингредиенты',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (widget.recipe.ingredients.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Ингредиенты не указаны',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ...widget.recipe.ingredients.map((ingredient) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF374151)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ingredient.name,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              Text(
                                '${ingredient.amount}${ingredient.unit != null ? ' ${ingredient.unit}' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                              if (ingredient.calories != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${ingredient.calories} ккал',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 32),

                    // Инструкции
                    const Text(
                      'Готовить',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (widget.recipe.instructions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Инструкции не указаны',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ...widget.recipe.instructions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final instruction = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF374151)
                                        : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    instruction,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 32),

                    // Кнопка удаления (если это рецепт пользователя)
                    if (widget.recipe.userId.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text(
                            'Удалить рецепт',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionInfo(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ApiHelper.deleteRecipe(widget.recipe.id);
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Рецепт удален')),
          );
          Navigator.pop(context, true); // Возвращаем true для обновления списка
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Ошибка удаления рецепта')),
          );
        }
      }
    }
  }
}
