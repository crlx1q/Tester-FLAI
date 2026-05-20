import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/api_helper.dart';
import '../../providers/user_provider.dart';

class FriendProgressScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendUsername;

  const FriendProgressScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendUsername,
  });

  @override
  State<FriendProgressScreen> createState() => _FriendProgressScreenState();
}

class _FriendProgressScreenState extends State<FriendProgressScreen> {
  Map<String, dynamic>? _friendData;
  Map<String, dynamic>? _todayData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final result = await ApiHelper.getFriendProgress(widget.friendId);
    if (mounted && result['success']) {
      setState(() {
        _friendData = result['friend'];
        _todayData = result['today'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friendData == null
              ? const Center(child: Text('Не удалось загрузить данные'))
              : RefreshIndicator(
                  onRefresh: _loadProgress,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 20),
                        _buildComparisonCard(isDark),
                        const SizedBox(height: 16),
                        _buildMacroComparison(isDark),
                        const SizedBox(height: 16),
                        _buildWaterComparison(isDark),
                        const SizedBox(height: 20),
                        _buildFriendFoodList(isDark),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final goal = _friendData!['goal'];
    String goalText;
    switch (goal) {
      case 'lose_weight': goalText = 'Похудение'; break;
      case 'gain_muscle': goalText = 'Набор массы'; break;
      case 'maintain': goalText = 'Поддержание'; break;
      default: goalText = 'Не указана';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isDark ? const Color(0xFF475569) : const Color(0xFFBAE6FD),
            child: Text(
              widget.friendName[0].toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (widget.friendUsername != null)
                  Text(
                    '@${widget.friendUsername}',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                const SizedBox(height: 4),
                Text('Цель: $goalText', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
          if (_friendData!['streak'] != null && _friendData!['streak'] > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF4500)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_friendData!['streak']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(bool isDark) {
    final userProvider = context.read<UserProvider>();
    final myCalories = userProvider.user?.dailyCalories ?? 2000;
    final friendCalories = _friendData!['dailyCalories'] ?? 2000;
    final friendConsumed = _todayData!['totalCalories'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Калории сегодня',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _buildProgressRow(
            label: widget.friendName,
            consumed: friendConsumed,
            target: friendCalories,
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            label: 'Вы',
            consumed: 0, // Will be filled from actual data
            target: myCalories,
            color: Colors.green,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int consumed,
    required int target,
    required Color color,
    required bool isDark,
  }) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
            Text('$consumed / $target ккал', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroComparison(bool isDark) {
    final macros = _todayData!['totalMacros'] ?? {};
    final targetMacros = _friendData!['macros'] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Макронутриенты',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildMacroItem('Белки', (macros['protein'] ?? 0).toDouble(), (targetMacros['protein'] ?? 0).toDouble(), const Color(0xFFEF5350), isDark)),
              const SizedBox(width: 10),
              Expanded(child: _buildMacroItem('Углеводы', (macros['carbs'] ?? 0).toDouble(), (targetMacros['carbs'] ?? 0).toDouble(), const Color(0xFFFFA726), isDark)),
              const SizedBox(width: 10),
              Expanded(child: _buildMacroItem('Жиры', (macros['fat'] ?? 0).toDouble(), (targetMacros['fat'] ?? 0).toDouble(), const Color(0xFF42A5F5), isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, double consumed, double target, Color color, bool isDark) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${consumed.round()} / ${target.round()}г',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
        ),
      ],
    );
  }

  Widget _buildWaterComparison(bool isDark) {
    final water = _todayData!['water'] ?? 0;
    final waterTarget = _friendData!['waterTarget'] ?? 2000;
    final glasses = (water / 250).floor();
    final targetGlasses = (waterTarget / 250).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вода', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                Text('$glasses / $targetGlasses стаканов', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
          Text(
            '${water} мл',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendFoodList(bool isDark) {
    final foods = List<Map<String, dynamic>>.from(_todayData!['foods'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Блюда за сегодня',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 12),
        if (foods.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Пока ничего не съедено',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          )
        else
          ...foods.map((food) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food['name'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${food['mealType'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${food['calories'] ?? 0} ккал',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }
}
