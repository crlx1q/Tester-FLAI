import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/api_helper.dart';
import '../../utils/image_helper.dart';
import '../../models/food_model.dart';

class MyFoodsScreen extends StatefulWidget {
  const MyFoodsScreen({super.key});

  @override
  State<MyFoodsScreen> createState() => _MyFoodsScreenState();
}

class _MyFoodsScreenState extends State<MyFoodsScreen> {
  List<FoodModel> _foods = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, breakfast, lunch, dinner, snack

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);
    final result = await ApiHelper.getFoodHistory();
    if (result['success']) {
      setState(() {
        _foods = (result['foods'] as List)
            .map((f) => FoodModel.fromJson(f))
            .toList();
      });
    }
    setState(() => _isLoading = false);
  }

  List<FoodModel> get _filteredFoods {
    if (_filter == 'all') return _foods;
    return _foods.where((f) => _getMealTypeKey(f.mealType) == _filter).toList();
  }

  String _getMealTypeKey(String mealType) {
    final lower = mealType.toLowerCase();
    if (lower.contains('завтрак') || lower.contains('breakfast')) return 'breakfast';
    if (lower.contains('обед') || lower.contains('lunch')) return 'lunch';
    if (lower.contains('ужин') || lower.contains('dinner')) return 'dinner';
    return 'snack';
  }

  Map<String, List<FoodModel>> _groupByDate(List<FoodModel> foods) {
    final map = <String, List<FoodModel>>{};
    for (final food in foods) {
      final key = DateFormat('yyyy-MM-dd').format(food.timestamp);
      map.putIfAbsent(key, () => []);
      map[key]!.add(food);
    }
    return map;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Сегодня';
    if (target == yesterday) return 'Вчера';
    return DateFormat('d MMMM, EEEE', 'ru').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredFoods;
    final grouped = _groupByDate(filtered);
    final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Stats
    final totalFoods = _foods.length;
    final totalCalories = _foods.fold<int>(0, (sum, f) => sum + f.calories);
    final uniqueFoods = _foods.map((f) => f.name.toLowerCase()).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои блюда', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foods.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadFoods,
                  child: CustomScrollView(
                    slivers: [
                      // Stats header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: _buildStatsRow(isDark, totalFoods, totalCalories, uniqueFoods),
                        ),
                      ),
                      // Filter chips
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildFilterChips(isDark),
                        ),
                      ),
                      // Food list grouped by date
                      ...dateKeys.expand((dateKey) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  _formatDateHeader(dateKey),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${grouped[dateKey]!.fold<int>(0, (s, f) => s + f.calories)} ккал',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildFoodTile(grouped[dateKey]![i], isDark),
                            childCount: grouped[dateKey]!.length,
                          ),
                        ),
                      ]),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'Пока нет записей',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 8),
          Text(
            'Сфотографируйте блюдо на главном экране',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, int totalFoods, int totalCalories, int uniqueFoods) {
    return Row(
      children: [
        _buildStatChip(isDark, '$totalFoods', 'записей', Icons.list_alt),
        const SizedBox(width: 8),
        _buildStatChip(isDark, '$uniqueFoods', 'блюд', Icons.restaurant_menu),
        const SizedBox(width: 8),
        _buildStatChip(isDark, '${(totalCalories / (totalFoods == 0 ? 1 : totalFoods)).round()}', 'ккал/блюдо', Icons.local_fire_department),
      ],
    );
  }

  Widget _buildStatChip(bool isDark, String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF8A5B)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      ('all', 'Все'),
      ('breakfast', 'Завтрак'),
      ('lunch', 'Обед'),
      ('dinner', 'Ужин'),
      ('snack', 'Перекус'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = f.$1),
              selectedColor: const Color(0xFFFF8A5B).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFFFF8A5B),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFFFF8A5B)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoodTile(FoodModel food, bool isDark) {
    return Dismissible(
      key: Key(food.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить блюдо?'),
            content: Text('Удалить "${food.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          final result = await ApiHelper.deleteFood(food.id);
          if (result['success']) {
            setState(() => _foods.removeWhere((f) => f.id == food.id));
            return true;
          }
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: food.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageHelper.buildImage(food.imageUrl, fit: BoxFit.cover, errorWidget: const Icon(Icons.restaurant, size: 24)),
                    )
                  : Icon(Icons.restaurant, size: 24, color: isDark ? Colors.white38 : Colors.black26),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Б ${food.macros.protein.round()}г · Ж ${food.macros.fat.round()}г · У ${food.macros.carbs.round()}г',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ],
              ),
            ),
            // Calories + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.calories} ккал',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm').format(food.timestamp),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
