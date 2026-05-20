import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/limits_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/api_helper.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  State<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final limitsProvider = context.watch<LimitsProvider>();
    final isDark = themeProvider.isDarkMode;
    final limits = limitsProvider.limits;
    
    // Use server-provided data for consistency
    final now = DateTime.now();
    final startDate = limits?.startedAt ?? now;
    final expiresAt = limits?.expiresAt;
    final daysRemaining = limits?.remainingDays ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали подписки'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRO Badge Header - Horizontal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRO подписка',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Активна',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Subscription Info
            _buildInfoCard(
              isDark: isDark,
              title: 'Информация о подписке',
              children: [
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Дата оформления',
                  value: DateFormat('d MMMM yyyy', 'ru').format(startDate),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.event_available,
                  label: 'Действительна до',
                  value: expiresAt != null 
                      ? DateFormat('d MMMM yyyy', 'ru').format(expiresAt.subtract(const Duration(days: 1)))
                      : 'Не указано',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.access_time,
                  label: 'Осталось дней',
                  value: daysRemaining > 0 
                      ? '$daysRemaining ${_getDaysWord(daysRemaining)}'
                      : 'Подписка истекла',
                  isDark: isDark,
                  valueColor: daysRemaining > 0 
                      ? const Color(0xFFF97316) 
                      : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Usage Statistics
            if (limits != null)
              _buildInfoCard(
                isDark: isDark,
                title: 'Использование',
                children: [
                  _buildUsageRow(
                    icon: Icons.photo_camera,
                    label: 'Фото',
                    value: 'Неограниченно',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildUsageRow(
                    icon: Icons.chat_bubble,
                    label: 'Сообщения',
                    value: 'Неограниченно',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildUsageRow(
                    icon: Icons.restaurant_menu,
                    label: 'Рецепты',
                    value: 'Неограниченно',
                    isDark: isDark,
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Benefits
            _buildInfoCard(
              isDark: isDark,
              title: 'Преимущества PRO',
              children: [
                _buildBenefitItem('Неограниченное количество фото', isDark),
                _buildBenefitItem('Неограниченные сообщения с AI', isDark),
                _buildBenefitItem('Неограниченные рецепты', isDark),
                _buildBenefitItem('Приоритетная поддержка', isDark),
                _buildBenefitItem('Без рекламы', isDark),
                _buildBenefitItem('Ранний доступ к новым функциям', isDark),
              ],
            ),

            const SizedBox(height: 24),

            // Cancel Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _showCancelDialog(context, isDark);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Отменить подписку',
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppTheme.primaryOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFF97316),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFF97316)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Отменить подписку?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите отменить PRO подписку? Вы потеряете доступ ко всем преимуществам.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: _isCancelling ? null : () => _cancelSubscription(context),
            child: _isCancelling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Отменить подписку',
                    style: TextStyle(color: Colors.red),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription(BuildContext context) async {
    setState(() {
      _isCancelling = true;
    });

    try {
      final result = await ApiHelper.cancelSubscription();

      if (!mounted) return;

      if (result['success']) {
        // Обновляем провайдеры
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final limitsProvider = Provider.of<LimitsProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Получаем токен для обновления лимитов
        final token = await authProvider.getToken();
        
        await userProvider.loadProfile();
        if (token != null) {
          await limitsProvider.loadLimits(token, ApiHelper.baseUrl);
        }

        Navigator.pop(context); // Закрываем диалог
        Navigator.pop(context); // Возвращаемся на экран профиля

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подписка успешно отменена'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.pop(context); // Закрываем диалог
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ошибка отмены подписки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      Navigator.pop(context); // Закрываем диалог
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка соединения с сервером'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
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
