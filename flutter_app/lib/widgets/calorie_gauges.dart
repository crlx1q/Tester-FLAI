import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/theme.dart';

// ВАРИАНТ 1: Простой полукруг (текущий)
class CalorieGauge1 extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieGauge1({
    super.key,
    required this.consumed,
    required this.target,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(240, 120),
                  painter: _SimpleGaugePainter(
                    progress: percentage,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Positioned(
                  top: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remaining.toString(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Осталось ккал'),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  child: _StatText(consumed.toString(), 'Съедено'),
                ),
                Positioned(
                  top: 20,
                  right: 0,
                  child: _StatText(burned.toString(), 'Сожжено'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ВАРИАНТ 2: С градиентом и тенью
class CalorieGauge2 extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieGauge2({
    super.key,
    required this.consumed,
    required this.target,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withOpacity(0.05),
            AppTheme.primaryPink.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(240, 120),
                  painter: _GradientGaugePainter(progress: percentage),
                ),
                Positioned(
                  top: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          remaining.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text('Осталось ккал'),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  child: _StatText(consumed.toString(), 'Съедено'),
                ),
                Positioned(
                  top: 20,
                  right: 0,
                  child: _StatText(burned.toString(), 'Сожжено'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ВАРИАНТ 3: 3D эффект
class CalorieGauge3 extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieGauge3({
    super.key,
    required this.consumed,
    required this.target,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Тень
                Positioned(
                  top: 10,
                  child: CustomPaint(
                    size: const Size(240, 120),
                    painter: _SimpleGaugePainter(
                      progress: percentage,
                      color: Colors.black12,
                    ),
                  ),
                ),
                // Основной
                CustomPaint(
                  size: const Size(240, 120),
                  painter: _3DGaugePainter(progress: percentage),
                ),
                Positioned(
                  top: 90,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              remaining.toString(),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                            const Text('Осталось', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  child: _StatBox(consumed.toString(), 'Съедено', Colors.orange),
                ),
                Positioned(
                  top: 20,
                  right: 0,
                  child: _StatBox(burned.toString(), 'Сожжено', Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ВАРИАНТ 4: Минималистичный
class CalorieGauge4 extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieGauge4({
    super.key,
    required this.consumed,
    required this.target,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Просто прогресс бар
          Row(
            children: [
              Text('$consumed', style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              Text('$target', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    remaining.toString(),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const Text('Осталось ккал'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ВАРИАНТ 5: С анимацией (цветная шкала)
class CalorieGauge5 extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieGauge5({
    super.key,
    required this.consumed,
    required this.target,
    required this.burned,
  });

  Color _getProgressColor(double percentage) {
    if (percentage < 0.5) return Colors.green;
    if (percentage < 0.8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);
    final color = _getProgressColor(percentage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(240, 120),
                  painter: _ColorfulGaugePainter(
                    progress: percentage,
                    color: color,
                  ),
                ),
                Positioned(
                  top: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remaining.toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const Text('Осталось ккал'),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  child: _StatText(consumed.toString(), 'Съедено'),
                ),
                Positioned(
                  top: 20,
                  right: 0,
                  child: _StatText(burned.toString(), 'Сожжено'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widgets
class _StatText extends StatelessWidget {
  final String value;
  final String label;

  const _StatText(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

// Painters
class _SimpleGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SimpleGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GradientGaugePainter extends CustomPainter {
  final double progress;

  _GradientGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background with gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey[300]!, Colors.grey[100]!],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress with gradient
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [AppTheme.primaryOrange, AppTheme.primaryPink],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradientGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _3DGaugePainter extends CustomPainter {
  final double progress;

  _3DGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress with 3D effect
    if (progress > 0) {
      // Shadow layer
      final shadowPaint = Paint()
        ..color = AppTheme.primaryOrange.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        shadowPaint,
      );

      // Main layer
      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [AppTheme.primaryOrange, AppTheme.primaryPink],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _3DGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ColorfulGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ColorfulGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColorfulGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
