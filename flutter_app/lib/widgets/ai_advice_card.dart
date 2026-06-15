import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/limits_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/api_helper.dart';

class AiAdviceCard extends StatefulWidget {
  const AiAdviceCard({super.key});

  @override
  State<AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends State<AiAdviceCard> {
  String? _advice;
  String? _suggestedMeal;
  bool _isLoading = false;
  String? _errorMessage;
  int? _usageCurrent;
  int? _usageMax;

  static const _cacheKey = 'ai_advice_cache';

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  String _getMealTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'breakfast';
    if (hour >= 12 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 21) return 'dinner';
    return 'snack';
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
      final savedDate = data['date'] as String?;
      final savedSlot = data['slot'] as String?;

      if (savedDate == _getCacheDate() && savedSlot == _getMealTimeSlot()) {
        if (mounted) {
          setState(() {
            _advice = data['advice'];
            _suggestedMeal = data['suggestedMeal'];
            _usageCurrent = data['usageCurrent'];
            _usageMax = data['usageMax'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'date': _getCacheDate(),
      'slot': _getMealTimeSlot(),
      'advice': _advice,
      'suggestedMeal': _suggestedMeal,
      'usageCurrent': _usageCurrent,
      'usageMax': _usageMax,
    });
    await prefs.setString(_cacheKey, data);
  }

  Future<void> _refreshLimits() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final limitsProvider = Provider.of<LimitsProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token != null) {
      limitsProvider.refresh(token, ApiHelper.baseUrl);
    }
  }

  Future<void> _loadAdvice() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiHelper.getAiMealAdvice();
      if (mounted) {
        if (result['success']) {
          final usage = result['usage'];
          setState(() {
            _advice = result['advice'];
            _suggestedMeal = result['suggestedMeal'];
            if (usage != null) {
              _usageCurrent = usage['current'];
              _usageMax = usage['max'];
            }
            _isLoading = false;
          });
          _saveToCache();
          // Обновляем глобальные лимиты
          _refreshLimits();
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Ошибка';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка подключения';
          _isLoading = false;
        });
      }
    }
  }

  String _getMealTimeLabel() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'завтрак';
    if (hour >= 12 && hour < 16) return 'обед';
    if (hour >= 16 && hour < 21) return 'ужин';
    return 'перекус';
  }

  String _getMealTimeQuestion() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Что мне поесть на завтрак?';
    if (hour >= 12 && hour < 16) return 'Что мне поесть на обед?';
    if (hour >= 16 && hour < 21) return 'Что мне поесть на ужин?';
    return 'Что мне перекусить?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              : const Color(0xFFFBBF24).withValues(alpha: 0.3),
        ),
      ),
      child: _isLoading
          ? _buildLoading()
          : _advice != null
              ? _buildContent(isDark)
              : _buildButton(isDark),
    );
  }

  Widget _buildButton(bool isDark) {
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
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Совет ИИ на ${_getMealTimeLabel()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 13, color: Colors.red.shade400),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadAdvice,
            icon: const Icon(Icons.restaurant, size: 18),
            label: Text(_getMealTimeQuestion()),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFFF6B35) : const Color(0xFFFF8A5B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
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
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Совет ИИ на ${_getMealTimeLabel()}',
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
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
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
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_outlined, size: 16, color: isDark ? Colors.white70 : const Color(0xFFFF6B35)),
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
        if (_usageCurrent != null && _usageMax != null) ...[
          const SizedBox(height: 8),
          Text(
            '$_usageCurrent/$_usageMax советов сегодня',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ],
    );
  }
}
