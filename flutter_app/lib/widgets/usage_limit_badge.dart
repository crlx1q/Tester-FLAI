import 'package:flutter/material.dart';
import '../models/usage_limits.dart';

class UsageLimitBadge extends StatelessWidget {
  final UsageInfo usageInfo;
  final String label;
  final IconData icon;
  
  const UsageLimitBadge({
    Key? key,
    required this.usageInfo,
    required this.label,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLimitReached = usageInfo.isLimitReached;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLimitReached 
            ? Colors.red.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLimitReached 
              ? Colors.red.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isLimitReached ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            'Осталось ${usageInfo.remaining}/${usageInfo.max} $label',
            style: TextStyle(
              fontSize: 12,
              color: isLimitReached ? Colors.red : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Виджет для AppBar
class AppBarLimitBadge extends StatelessWidget {
  final UsageInfo usageInfo;
  final String emoji;
  
  const AppBarLimitBadge({
    Key? key,
    required this.usageInfo,
    required this.emoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLimitReached = usageInfo.isLimitReached;
    
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLimitReached
            ? Colors.red.withOpacity(0.2)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '${usageInfo.remaining}/${usageInfo.max}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLimitReached ? Colors.red : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
