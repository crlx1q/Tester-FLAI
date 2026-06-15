import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/firebase_messaging_service.dart';
import '../../utils/api_helper.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _friendActivity = true;
  bool _mealReminders = true;
  bool _updates = true;

  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 19, minute: 0);

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _friendActivity = prefs.getBool('notif_friend_activity') ?? true;
      _mealReminders = prefs.getBool('notif_meal_reminders') ?? true;
      _updates = prefs.getBool('notif_updates') ?? true;
      _breakfastTime = _parseTime(prefs.getString('notif_breakfast_time')) ?? const TimeOfDay(hour: 8, minute: 0);
      _lunchTime = _parseTime(prefs.getString('notif_lunch_time')) ?? const TimeOfDay(hour: 13, minute: 0);
      _dinnerTime = _parseTime(prefs.getString('notif_dinner_time')) ?? const TimeOfDay(hour: 19, minute: 0);
      _isLoading = false;
    });
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('notif_friend_activity', _friendActivity);
    await prefs.setBool('notif_meal_reminders', _mealReminders);
    await prefs.setBool('notif_updates', _updates);
    await prefs.setString('notif_breakfast_time', _formatTime(_breakfastTime));
    await prefs.setString('notif_lunch_time', _formatTime(_lunchTime));
    await prefs.setString('notif_dinner_time', _formatTime(_dinnerTime));

    // Sync with server
    await ApiHelper.updateNotificationSettings({
      'friendActivity': _friendActivity && _notificationsEnabled,
      'mealReminders': _mealReminders && _notificationsEnabled,
      'updates': _updates && _notificationsEnabled,
      'reminderTimes': {
        'breakfast': _mealReminders && _notificationsEnabled ? _formatTime(_breakfastTime) : null,
        'lunch': _mealReminders && _notificationsEnabled ? _formatTime(_lunchTime) : null,
        'dinner': _mealReminders && _notificationsEnabled ? _formatTime(_dinnerTime) : null,
      },
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки сохранены'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _pickTime(String meal) async {
    final initial = meal == 'breakfast' ? _breakfastTime : meal == 'lunch' ? _lunchTime : _dinnerTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (meal == 'breakfast') _breakfastTime = picked;
        if (meal == 'lunch') _lunchTime = picked;
        if (meal == 'dinner') _dinnerTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master toggle
                  _buildSection(
                    isDark,
                    title: 'Уведомления',
                    children: [
                      _buildToggleTile(
                        isDark,
                        icon: Icons.notifications_active_outlined,
                        title: 'Включить уведомления',
                        subtitle: 'Получать все уведомления от приложения',
                        value: _notificationsEnabled,
                        onChanged: (v) async {
                          if (v) {
                            final status = await Permission.notification.request();
                            if (status.isGranted) {
                              setState(() => _notificationsEnabled = true);
                            } else if (status.isPermanentlyDenied) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Разрешите уведомления в настройках телефона'),
                                    action: SnackBarAction(
                                      label: 'Открыть',
                                      onPressed: () => openAppSettings(),
                                    ),
                                  ),
                                );
                              }
                            }
                          } else {
                            setState(() => _notificationsEnabled = false);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Meal reminders section
                  _buildSection(
                    isDark,
                    title: 'Напоминания о приёмах пищи',
                    children: [
                      _buildToggleTile(
                        isDark,
                        icon: Icons.alarm_outlined,
                        title: 'Напоминания о еде',
                        subtitle: 'Напомнить записать завтрак, обед и ужин',
                        value: _mealReminders,
                        enabled: _notificationsEnabled,
                        onChanged: (v) => setState(() => _mealReminders = v),
                      ),
                      if (_mealReminders && _notificationsEnabled) ...[
                        const Divider(height: 1),
                        _buildTimeTile(isDark, 'Завтрак', _breakfastTime, () => _pickTime('breakfast')),
                        const Divider(height: 1),
                        _buildTimeTile(isDark, 'Обед', _lunchTime, () => _pickTime('lunch')),
                        const Divider(height: 1),
                        _buildTimeTile(isDark, 'Ужин', _dinnerTime, () => _pickTime('dinner')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Other notifications
                  _buildSection(
                    isDark,
                    title: 'Другие уведомления',
                    children: [
                      _buildToggleTile(
                        isDark,
                        icon: Icons.people_outlined,
                        title: 'Активность друзей',
                        subtitle: 'Заявки в друзья и достижения друзей',
                        value: _friendActivity,
                        enabled: _notificationsEnabled,
                        onChanged: (v) => setState(() => _friendActivity = v),
                      ),
                      const Divider(height: 1),
                      _buildToggleTile(
                        isDark,
                        icon: Icons.system_update_outlined,
                        title: 'Обновления приложения',
                        subtitle: 'Новые версии и важные новости',
                        value: _updates,
                        enabled: _notificationsEnabled,
                        onChanged: (v) => setState(() => _updates = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A5B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(bool isDark, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (enabled ? const Color(0xFFFF8A5B) : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: enabled ? const Color(0xFFFF8A5B) : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value && enabled,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: const Color(0xFFFF8A5B),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile(bool isDark, String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeDisplay(time),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}
