import 'package:flutter/material.dart';
import '../utils/api_helper.dart';

class AiAdviceCard extends StatefulWidget {
  final VoidCallback? onRefresh;

  const AiAdviceCard({super.key, this.onRefresh});

  @override
  State<AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends State<AiAdviceCard> {
  String? _advice;
  String? _emoji;
  String? _suggestedMeal;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiHelper.getAiMealAdvice();
      if (mounted) {
        if (result['success']) {
          setState(() {
            _advice = result['advice'];
            _emoji = result['emoji'] ?? '✨';
            _suggestedMeal = result['suggestedMeal'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  String _getMealTimeLabel() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'на завтрак';
    if (hour >= 12 && hour < 16) return 'на обед';
    if (hour >= 16 && hour < 21) return 'на ужин';
    return 'на перекус';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFFFFF7ED), const Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF475569)
              : const Color(0xFFFBBF24).withOpacity(0.3),
        ),
      ),
      child: _isLoading
          ? _buildLoading()
          : _buildContent(isDark),
    );
  }

  Widget _buildLoading() {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text(
          'AI анализирует ваш рацион...',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Совет ИИ ${_getMealTimeLabel()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            GestureDetector(
              onTap: _loadAdvice,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_advice != null)
          Text(
            _advice!,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
            ),
          ),
        if (_suggestedMeal != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_emoji ?? '🥗', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _suggestedMeal!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
