import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/update_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/update_notification_widget.dart';
import 'edit_profile_screen.dart';
import 'my_foods_screen.dart';
import 'daily_summary_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = userProvider.user;
    final isDark = themeProvider.isDarkMode;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile header
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (user.subscription == 'pro')
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // Pro или Streak badge
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: (user.subscriptionType == 'pro' || user.isPro == true)
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFffd89b), Color(0xFF19547b)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFffd89b).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : (user.displayStreak > 0)
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
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                    boxShadow: user.streakStatus == 'active'
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF6B35).withOpacity(0.4),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    if (user.subscription == 'pro') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Update notification
            const UpdateNotificationWidget(),

            // Streak card
            if (user.displayStreak > 0)
              Container(
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: user.streakStatus == 'active'
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${user.displayStreak}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'дней подряд',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Рекорд: ${user.maxStreak} дней 🏆',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
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

            const SizedBox(height: 24),

            // Stats cards
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    '${user.weight?.toStringAsFixed(1) ?? '--'}',
                    'кг',
                    'Вес',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  _buildStatColumn(
                    '${user.height ?? '--'}',
                    'см',
                    'Рост',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  _buildStatColumn(
                    '${user.age ?? '--'}',
                    'лет',
                    'Возраст',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pro subscription banner (if not pro)
            if (user.subscription != 'pro') _buildProBanner(context),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButton(
              context,
              icon: Icons.summarize,
              label: 'Моя дневная сводка',
              gradient: AppTheme.primaryGradient,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailySummaryScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              context,
              icon: Icons.restaurant,
              label: 'Мои блюда',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyFoodsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              context,
              icon: Icons.edit,
              label: 'Редактировать профиль',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              context,
              icon: Icons.notifications_outlined,
              label: 'Уведомления',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скоро будет доступно')),
                );
              },
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              context,
              icon: Icons.help_outline,
              label: 'Помощь и поддержка',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скоро будет доступно')),
                );
              },
            ),

            const SizedBox(height: 32),

            // Logout button
            OutlinedButton(
              onPressed: () async {
                final authProvider = context.read<AuthProvider>();
                await authProvider.logout();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Выйти из аккаунта'),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String unit, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' $unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Обновитесь до PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Получите неограниченный доступ к AI-анализу, персональным рекомендациям и эксклюзивным рецептам!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скоро будет доступно')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Попробовать PRO'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient != null ? null : Theme.of(context).cardColor,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: gradient != null ? Colors.white : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: gradient != null ? Colors.white : null,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: gradient != null ? Colors.white : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
