import 'package:flutter/material.dart';

class ProBadge extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact; // New parameter for profile display
  final bool tiny; // New parameter for recipe author display
  
  const ProBadge({
    Key? key,
    this.size = 16,
    this.showText = true,
    this.compact = false,
    this.tiny = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tiny) {
      // Tiny style for recipe authors - same size as text
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 8,
              color: Colors.white,
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
      );
    }
    
    if (compact) {
      // Profile display style with rounded rectangle
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            const Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }
    
    // Original style
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.5,
        vertical: size * 0.2,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB923C).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: size,
            color: Colors.white,
          ),
          if (showText) ...[
            SizedBox(width: size * 0.25),
            Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.7,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
