import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  String? _summary;
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _errorMessage;
  bool _requiresPro = false;

  static const _cacheKey = 'daily_summary_cache';

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  String _getCacheDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      if (data['date'] == _getCacheDate()) {
        if (mounted) {
          setState(() {
            _summary = data['summary'];
            _stats = data['stats'] != null
                ? Map<String, dynamic>.from(data['stats'])
                : null;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'date': _getCacheDate(),
      'summary': _summary,
      'stats': _stats,
    });
    await prefs.setString(_cacheKey, data);
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requiresPro = false;
    });

    final result = await ApiHelper.getAiDailySummary();

    if (mounted) {
      if (result['success']) {
        setState(() {
          _summary = result['summary'];
          _stats = result['stats'] != null
              ? Map<String, dynamic>.from(result['stats'])
              : null;
          _isLoading = false;
        });
        _saveToCache();
      } else {
        setState(() {
          _errorMessage = result['message'];
          _requiresPro = result['requiresPro'] == true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневная сводка AI', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState(isDark)
          : _summary != null
              ? _buildContent(isDark)
              : _buildInitialState(isDark),
    );
  }

  Widget _buildInitialState(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Hero illustration
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI-анализ вашего дня',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI проанализирует все блюда, которые вы съели сегодня, '
            'оценит достижение ваших целей и даст персональные рекомендации на завтра.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          // Features list
          _buildFeatureItem(isDark, Icons.analytics_outlined, 'Оценка калорий и макросов'),
          _buildFeatureItem(isDark, Icons.restaurant_outlined, 'Анализ баланса питания'),
          _buildFeatureItem(isDark, Icons.tips_and_updates_outlined, 'Рекомендации на завтра'),
          _buildFeatureItem(isDark, Icons.psychology_outlined, 'Персональный подход к целям'),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _requiresPro
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _requiresPro ? Icons.workspace_premium : Icons.info_outline,
                    color: _requiresPro ? Colors.amber : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requiresPro ? null : _loadSummary,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text(_requiresPro ? 'Только для Pro' : 'Получить сводку'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A5B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Доступно для Pro подписки',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(bool isDark, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF8A5B)),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI анализирует ваш день...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Это может занять несколько секунд',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          if (_stats != null) _buildStatsSection(isDark),
          const SizedBox(height: 16),
          // AI Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                    : [const Color(0xFFFFF7ED), const Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFFBBF24).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Анализ AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _summary!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Refresh button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Обновить сводку'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    final totalCalories = _stats!['totalCalories'] ?? 0;
    final targetCalories = _stats!['targetCalories'] ?? 2000;
    final totalMacros = _stats!['totalMacros'] ?? {};
    final targetMacros = _stats!['targetMacros'] ?? {};
    final foodsCount = _stats!['foodsCount'] ?? 0;
    final calorieProgress = targetCalories > 0 ? (totalCalories / targetCalories).clamp(0.0, 1.5) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calorie progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Калории',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text(
                    '$totalCalories / $targetCalories ккал',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: calorieProgress.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFFF8A5B).withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    calorieProgress > 1.1 ? Colors.red : const Color(0xFFFF8A5B),
                  ),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(calorieProgress * 100).round()}% от цели · $foodsCount блюд',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Macros row
        Row(
          children: [
            _buildMacroCard(isDark, 'Белки', totalMacros['protein'] ?? 0, targetMacros['protein'] ?? 100, const Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            _buildMacroCard(isDark, 'Жиры', totalMacros['fat'] ?? 0, targetMacros['fat'] ?? 70, const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _buildMacroCard(isDark, 'Углеводы', totalMacros['carbs'] ?? 0, targetMacros['carbs'] ?? 250, const Color(0xFF10B981)),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroCard(bool isDark, String label, num current, num target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                  Text(
                    '${current.round()}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '/ ${target.round()}г',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
