import 'package:flutter/material.dart';
import '../../utils/api_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final result = await ApiHelper.getNotifications();
    if (mounted && result['success']) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(result['notifications'] ?? []);
        _unreadCount = result['unreadCount'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ApiHelper.markAllNotificationsRead();
    if (mounted) {
      setState(() {
        _unreadCount = 0;
        for (var n in _notifications) {
          n['read'] = true;
        }
      });
    }
  }

  Future<void> _deleteNotification(String id, int index) async {
    await ApiHelper.deleteNotification(id);
    if (mounted) {
      setState(() {
        _notifications.removeAt(index);
      });
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'friend_request': return Icons.person_add;
      case 'friend_accepted': return Icons.people;
      case 'friend_ate': return Icons.restaurant;
      case 'reminder': return Icons.alarm;
      case 'update': return Icons.system_update;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'friend_request': return Colors.blue;
      case 'friend_accepted': return Colors.green;
      case 'friend_ate': return Colors.orange;
      case 'reminder': return Colors.purple;
      case 'update': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 24) return '${diff.inHours} ч назад';
      if (diff.inDays < 7) return '${diff.inDays} дн назад';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Прочитать все', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: isDark ? Colors.white38 : Colors.black26),
                      const SizedBox(height: 16),
                      Text(
                        'Нет уведомлений',
                        style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return _buildNotificationTile(notif, index, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif, int index, bool isDark) {
    final isRead = notif['read'] == true;
    final type = notif['type'] as String?;
    final color = _getNotificationColor(type);

    return Dismissible(
      key: Key(notif['_id'] ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['_id'], index),
      child: Container(
        color: isRead
            ? Colors.transparent
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getNotificationIcon(type), color: color, size: 20),
          ),
          title: Text(
            notif['title'] ?? '',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notif['body'] ?? '',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(notif['createdAt']),
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () async {
            if (!isRead) {
              await ApiHelper.markNotificationRead(notif['_id']);
              setState(() {
                notif['read'] = true;
                _unreadCount = (_unreadCount - 1).clamp(0, 999);
              });
            }
          },
        ),
      ),
    );
  }
}
