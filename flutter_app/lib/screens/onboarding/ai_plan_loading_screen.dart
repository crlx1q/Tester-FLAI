import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class AIPlanLoadingScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onComplete;
  
  const AIPlanLoadingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<AIPlanLoadingScreen> createState() => _AIPlanLoadingScreenState();
}

class _AIPlanLoadingScreenState extends State<AIPlanLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  int _currentTextIndex = 0;
  bool _isComplete = false;
  Map<String, dynamic>? _result;

  final List<Map<String, dynamic>> _steps = [
    {'icon': Icons.analytics_outlined, 'text': 'Анализирую ваши данные'},
    {'icon': Icons.calculate_outlined, 'text': 'Рассчитываю базовый метаболизм'},
    {'icon': Icons.local_fire_department_outlined, 'text': 'Подбираю оптимальные калории'},
    {'icon': Icons.restaurant_outlined, 'text': 'Определяю макронутриенты'},
    {'icon': Icons.emoji_events_outlined, 'text': 'Создаю персональный план'},
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _startProcess();
  }

  Future<void> _startProcess() async {
    // Показываем каждый шаг
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() => _currentTextIndex = i);
      _fadeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Вызываем API
    try {
      final result = await widget.onComplete();
      if (!mounted) return;
      setState(() {
        _result = result;
        _isComplete = true;
      });
      
      // Небольшая задержка перед показом результата
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      
      if (result['success'] == true && result['aiPlan'] != null) {
        // Используем push вместо pushReplacement, чтобы можно было вернуть результат
        final planResult = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => AIPlanResultScreen(aiPlan: result['aiPlan']),
          ),
        );
        // Возвращаем результат из Result Screen обратно в Onboarding
        if (mounted) {
          Navigator.of(context).pop(planResult ?? result);
        }
      } else {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop({'success': false, 'message': e.toString()});
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentTextIndex];
    final progress = ((_currentTextIndex + 1) / _steps.length * 100).toInt();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Создание плана'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Круговой прогресс с иконкой
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                      ),
                    ),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentStep['icon'] as IconData,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Заголовок
                Text(
                  'AI создает ваш план',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Анимированный текст шага
                FadeTransition(
                  opacity: _fadeController,
                  child: Text(
                    currentStep['text'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 24),

                // Текст прогресса
                Text(
                  'Шаг ${_currentTextIndex + 1} из ${_steps.length} • $progress%',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Painter для вращающихся точек
class _DotsPainter extends CustomPainter {
  final Color color;

  _DotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Рисуем 4 точки по кругу
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Экран результата с AI планом
class AIPlanResultScreen extends StatelessWidget {
  final Map<String, dynamic> aiPlan;

  const AIPlanResultScreen({super.key, required this.aiPlan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryOrange.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Иконка успеха
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                // Заголовок
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Ваш персональный план готов!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Карточка с планом
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Цель - название
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  aiPlan['goalTitle'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Цель - описание
                          Text(
                            aiPlan['goalDescription'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),

                          // Целевой вес
                          _buildPlanItem(
                            icon: Icons.track_changes,
                            label: 'Целевой вес',
                            value: '${aiPlan['targetWeight']} кг',
                          ),

                          const SizedBox(height: 16),

                          // Калории
                          _buildPlanItem(
                            icon: Icons.local_fire_department,
                            label: 'Калории в день',
                            value: '${aiPlan['dailyCalories']} ккал',
                          ),

                          const SizedBox(height: 24),

                          // Макронутриенты
                          Text(
                            'Макронутриенты',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildPlanItem(
                            icon: Icons.fitness_center,
                            label: 'Белки',
                            value: '${aiPlan['macros']['protein']} г',
                          ),

                          const SizedBox(height: 12),

                          _buildPlanItem(
                            icon: Icons.cookie,
                            label: 'Жиры',
                            value: '${aiPlan['macros']['fat']} г',
                          ),

                          const SizedBox(height: 12),

                          _buildPlanItem(
                            icon: Icons.bakery_dining,
                            label: 'Углеводы',
                            value: '${aiPlan['macros']['carbs']} г',
                          ),

                          const SizedBox(height: 24),

                          // Вода
                          _buildPlanItem(
                            icon: Icons.water_drop,
                            label: 'Норма воды',
                            value: '${aiPlan['waterGlasses']} стаканов (${aiPlan['waterGlasses'] * 100} мл)',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Кнопка
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Возвращаемся на 2 экрана назад (через loading screen и onboarding)
                      Navigator.of(context).pop({'success': true});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Начать путь',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
