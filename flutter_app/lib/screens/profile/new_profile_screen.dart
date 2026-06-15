import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/user_provider.dart';
import '../../providers/limits_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/update_provider.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import '../../utils/api_helper.dart';
import '../../utils/image_helper.dart';
import '../../widgets/pro_badge.dart';
import '../../widgets/update_notification_widget.dart';
import 'edit_profile_screen.dart';
import 'subscription_details_screen.dart';
import 'my_foods_screen.dart';
import 'daily_summary_screen.dart';
import '../notifications/notification_settings_screen.dart';

class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({super.key});

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoadingWeekly = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyProgress();
  }

  Future<void> _loadWeeklyProgress() async {
    final result = await ApiHelper.getWeeklyProgress();
    if (result['success'] && mounted) {
      setState(() {
        _weeklyData = List<Map<String, dynamic>>.from(result['data']);
        _isLoadingWeekly = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingWeekly = false);
    }
  }

  String _getGoalText(String? goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Похудеть';
      case 'gain_muscle':
        return 'Набрать массу';
      case 'maintain_weight':
        return 'Удержать вес';
      default:
        return 'Здоровое питание';
    }
  }

  String _getActivityText(String? activity) {
    switch (activity) {
      case 'low':
        return 'малоактивный';
      case 'moderate':
        return 'умеренно активный';
      case 'high':
        return 'очень активный';
      default:
        return 'умеренно активный';
    }
  }

  void _showUsernameDialog(String? currentUsername) {
    final controller = TextEditingController(text: currentUsername ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Установить @username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixText: '@',
            hintText: 'my_username',
            helperText: 'Латинские буквы, цифры, _ (3-20 символов)',
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final username = controller.text.trim().toLowerCase();
              if (username.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Минимум 3 символа'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              final result = await ApiHelper.updateUsername(username);
              if (mounted) {
                if (result['success']) {
                  context.read<UserProvider>().loadProfile();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username обновлён'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Ошибка'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final limitsProvider = context.watch<LimitsProvider>();
    final user = userProvider.user;
    final isDark = themeProvider.isDarkMode;
    final isPro = limitsProvider.isPro;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Уведомление об обновлении
            const UpdateNotificationWidget(),
            
            // Основная карточка профиля
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Аватар и информация
                  Row(
                    children: [
                      // Аватар с огоньком
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white24 : Colors.black12,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: user.avatar != null
                                  ? ImageHelper.buildImage(
                                      user.avatar,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryOrange,
                                              AppTheme.primaryOrange.withOpacity(0.8),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryOrange,
                                            AppTheme.primaryOrange.withOpacity(0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          // Streak badge
                          Positioned(
                          right: 0,
                          bottom: 0,
                          child: isPro
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEC4899).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'PRO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : user.displayStreak > 0
                                  ? Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: user.streakStatus == 'active'
                                            ? const LinearGradient(
                                                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: user.streakStatus != 'active'
                                            ? Colors.grey[400]
                                            : null,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFFFF4E6),
                                          width: 2,
                                        ),
                                        boxShadow: user.streakStatus == 'active'
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFFF6B35).withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Информация
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.username != null && user.username!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () => _showUsernameDialog(user.username),
                                child: Text(
                                  '@${user.username}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (user.username == null || user.username!.isEmpty) ...[
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () => _showUsernameDialog(null),
                                child: Text(
                                  'Установить @username',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${user.age ?? 25} лет • ${user.gender == 'female' ? 'женщина' : 'мужчина'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Кнопка цели
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            if (user.goalDescription != null && user.goalDescription!.isNotEmpty) {
                              _showGoalDialog(user.goal ?? 'Цель', user.goalDescription!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryOrange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IntrinsicWidth(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                    color: AppTheme.primaryOrange,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      user.goal ?? 'Цель не указана',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user.goalDescription != null && user.goalDescription!.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: AppTheme.primaryOrange.withOpacity(0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Subscription Block
                  _buildSubscriptionCard(isPro, limitsProvider, isDark),
                  
                  const SizedBox(height: 16),
                  
                  // Рост и Вес
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.height,
                          label: 'Рост',
                          value: '${user.height ?? 170} см',
                          isDark: isDark,
                          iconColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Вес',
                          value: '${user.weight?.toStringAsFixed(1) ?? '70.0'} кг',
                          isDark: isDark,
                          iconColor: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Цель (target weight)
                  _buildStatCard(
                    icon: Icons.track_changes,
                    label: 'Целевой вес',
                    value: user.targetWeight != null ? '${user.targetWeight} кг' : 'Не указан',
                    isDark: isDark,
                    isFullWidth: true,
                    iconColor: Colors.red,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Активность
                  _buildStatCard(
                    icon: Icons.directions_run,
                    label: 'Активность',
                    value: _getActivityText(user.activityLevel),
                    isDark: isDark,
                    isFullWidth: true,
                    iconColor: Colors.green,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Ограничения
                  Text(
                    'Ограничения',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (user.allergies.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.allergies.map((allergy) {
                        String allergyText = allergy;
                        if (allergy == 'lactose') allergyText = 'без лактозы';
                        else if (allergy == 'gluten') allergyText = 'без глютена';
                        else if (allergy == 'nuts') allergyText = 'без орехов';
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red.withOpacity(0.15) : const Color(0xFFFFE4E4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block,
                                size: 14,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                allergyText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      'Нет ограничений',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
            
            // Streak card
            if (user.displayStreak > 0) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showStreakCalendar(context),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: user.streakStatus == 'active'
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: user.streakStatus != 'active'
                        ? Colors.grey[400]
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: user.streakStatus == 'active'
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${user.displayStreak}',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'дней подряд',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Рекорд: ${user.maxStreak} дней',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user.streakStatus == 'at_risk') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Добавьте активность сегодня, чтобы не потерять серию!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // График прогресса за неделю
            Text(
              'Прогресс за неделю',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: _isLoadingWeekly
                  ? const Center(child: CircularProgressIndicator())
                  : _weeklyData.isEmpty
                      ? const Center(child: Text('Нет данных за неделю'))
                      : Builder(
                          builder: (context) {
                            // Находим максимальное значение для нормализации
                            double maxPercentage = 100;
                            for (var dayData in _weeklyData) {
                              final percentage = (dayData['percentage'] ?? 0).toDouble();
                              if (percentage > maxPercentage) {
                                maxPercentage = percentage;
                              }
                            }
                            
                            // Добавляем небольшой отступ сверху (10%)
                            final maxY = maxPercentage * 1.1;
                            
                            return BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxY,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                                        if (value.toInt() < days.length) {
                                          return Text(
                                            days[value.toInt()],
                                            style: const TextStyle(fontSize: 12),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(
                                  _weeklyData.length,
                                  (index) {
                                    final dayData = _weeklyData[index];
                                    final percentage = dayData['percentage'] ?? 0;
                                    final color = percentage > 100 ? Colors.orange : Colors.green;
                                    return _buildBarGroup(index, percentage.toDouble(), color);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            const SizedBox(height: 32),
            
            // Кнопки действий
            _buildActionButton(
              context,
              icon: Icons.restaurant,
              label: 'Мои блюда',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyFoodsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.summarize,
              label: 'Дневная сводка AI',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.notifications_outlined,
              label: 'Настройки уведомлений',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              label: 'Сменить тему',
              onTap: () {
                themeProvider.toggleTheme();
              },
            ),
            
            const SizedBox(height: 32),
            
            // Выход
            OutlinedButton(
              onPressed: () async {
                final authProvider = context.read<AuthProvider>();
                await authProvider.logout();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Выйти из аккаунта', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isFullWidth = false,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppTheme.primaryOrange;
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  void _showStreakCalendar(BuildContext context) async {
    // Показываем диалог с загрузкой
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Загружаем активные дни с сервера
    final now = DateTime.now();
    final result = await ApiHelper.getMonthlyActiveDays(
      year: now.year,
      month: now.month,
    );
    
    // Закрываем индикатор загрузки
    if (context.mounted) Navigator.pop(context);
    
    // Парсим активные дни
    final activeDays = <DateTime>{};
    if (result['success'] && result['data'] != null) {
      final daysData = result['data'] as List<dynamic>;
      for (var dateStr in daysData) {
        try {
          activeDays.add(DateTime.parse(dateStr));
        } catch (e) {
          // Пропускаем неверные даты
        }
      }
    }
    
    if (!context.mounted) return;
    
    final userProvider = context.read<UserProvider>();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Активность',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Календарь
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: DateTime.now(),
                  locale: 'ru_RU',
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, activeDays);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, activeDays, isToday: true);
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, activeDays, isOutside: true);
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                
                // Статистика
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBadge('Текущая серия', '${userProvider.user?.displayStreak ?? 0}', Icons.local_fire_department),
                    _buildStatBadge('Рекорд', '${userProvider.user?.maxStreak ?? 0}', Icons.emoji_events),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, Set<DateTime> activeDays, {bool isToday = false, bool isOutside = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayNormalized = DateTime(day.year, day.month, day.day);
    
    final isPast = dayNormalized.isBefore(today);
    final isFuture = dayNormalized.isAfter(today);
    final isActive = activeDays.any((d) => 
      d.year == day.year && d.month == day.month && d.day == day.day
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color? bgColor;
    Color? textColor;
    
    if (isOutside) {
      textColor = isDark ? Colors.grey[600] : Colors.grey[300];
    } else if (isFuture) {
      textColor = isDark ? Colors.grey[500] : Colors.grey[400];
    } else if (isToday) {
      if (isActive) {
        bgColor = Colors.orange;
        textColor = Colors.white;
      } else {
        bgColor = Colors.grey[400];
        textColor = Colors.white;
      }
    } else if (isPast) {
      if (isActive) {
        bgColor = Colors.orange;
        textColor = Colors.white;
      } else {
        bgColor = Colors.grey[400];
        textColor = Colors.white;
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildSubscriptionCard(bool isPro, LimitsProvider limitsProvider, bool isDark) {
    final limits = limitsProvider.limits;
    
    if (isPro) {
      // PRO user card
      return GestureDetector(
        onTap: () {
          // TODO: Navigate to subscription details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionDetailsScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRO подписка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Активна',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    final user = userProvider.user;
                    if (user == null) return const SizedBox();
                    
                    final daysRemaining = user.subscriptionRemainingDays;
                    final expiresAt = user.subscriptionExpiresAt;
                    
                    String expiryText = 'Не указано';
                    if (expiresAt != null) {
                      // Вычитаем 1 день для правильного отображения (подписка истекает в начале следующего дня)
                      final displayDate = expiresAt.subtract(const Duration(days: 1));
                      final day = displayDate.day;
                      final month = _getMonthName(displayDate.month);
                      final year = displayDate.year;
                      expiryText = '$day $month $year';
                    }
                    
                    String daysText = '$daysRemaining ${_getDaysWord(daysRemaining)}';
                    
                    return Column(
                      children: [
                        _buildSubscriptionInfo('Осталось дней', daysText, Icons.access_time, isDark),
                        const SizedBox(height: 8),
                        _buildSubscriptionInfo('Действительна до', expiryText, Icons.event_available, isDark),
                        const SizedBox(height: 8),
                        _buildProFeature('Без ограничений', Icons.all_inclusive, isDark),
                        const SizedBox(height: 8),
                        _buildProFeature('Приоритетная поддержка', Icons.support_agent, isDark),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // FREE user card - upgrade prompt
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Бесплатная версия',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Ограниченный доступ',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (limits != null) ...[
              _buildLimitRow('Фото', limits.photos.remaining, limits.photos.max, Icons.photo_camera, isDark),
              const SizedBox(height: 8),
              _buildLimitRow('Сообщения', limits.messages.remaining, limits.messages.max, Icons.chat_bubble, isDark),
              const SizedBox(height: 8),
              _buildLimitRow('Рецепты', limits.recipes.remaining, limits.recipes.max, Icons.restaurant_menu, isDark),
              const SizedBox(height: 8),
              _buildLimitRow('Советы AI', limits.mealAdvice.remaining, limits.mealAdvice.max, Icons.auto_awesome, isDark),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // TODO: Navigate to subscription page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Оформление подписки скоро будет доступно!')),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Оформить PRO подписку',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSubscriptionInfo(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFEC4899),
          size: 16,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildProFeature(String text, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 16,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitRow(String label, int remaining, int max, IconData icon, bool isDark) {
    final percentage = (remaining / max * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Spacer(),
            Text(
              '$remaining / $max',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining > 0 ? const Color(0xFFF97316) : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  void _showGoalDialog(String goalTitle, String goalDescription) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2937)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Иконка цели
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              
              // Название цели
              Text(
                goalTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Описание цели
              Text(
                goalDescription,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Кнопка закрыть
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  String _getDaysWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return 'день';
    } else if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }
}
