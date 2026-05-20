import 'package:flutter/material.dart';
import '../widgets/calorie_gauges.dart';

class GaugeDemoScreen extends StatelessWidget {
  const GaugeDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const int consumed = 846;
    const int target = 2314;
    const int burned = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите дизайн шкалы'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Нажмите на понравившийся вариант',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Вариант 1
          _buildGaugeCard(
            context,
            '1. Простой полукруг',
            'Чистый минимализм',
            CalorieGauge1(consumed: consumed, target: target, burned: burned),
            () => _selectGauge(context, 1),
          ),
          
          const SizedBox(height: 24),
          
          // Вариант 2
          _buildGaugeCard(
            context,
            '2. С градиентом',
            'Красочный и современный',
            CalorieGauge2(consumed: consumed, target: target, burned: burned),
            () => _selectGauge(context, 2),
          ),
          
          const SizedBox(height: 24),
          
          // Вариант 3
          _buildGaugeCard(
            context,
            '3. 3D эффект',
            'Объемный дизайн',
            CalorieGauge3(consumed: consumed, target: target, burned: burned),
            () => _selectGauge(context, 3),
          ),
          
          const SizedBox(height: 24),
          
          // Вариант 4
          _buildGaugeCard(
            context,
            '4. Минималистичный',
            'Простой прогресс бар',
            CalorieGauge4(consumed: consumed, target: target, burned: burned),
            () => _selectGauge(context, 4),
          ),
          
          const SizedBox(height: 24),
          
          // Вариант 5
          _buildGaugeCard(
            context,
            '5. Цветная шкала',
            'Меняет цвет по прогрессу',
            CalorieGauge5(consumed: consumed, target: target, burned: burned),
            () => _selectGauge(context, 5),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGaugeCard(
    BuildContext context,
    String title,
    String description,
    Widget gauge,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!, width: 2),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.blue, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            gauge,
          ],
        ),
      ),
    );
  }

  void _selectGauge(BuildContext context, int number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Вариант $number выбран!'),
        content: Text('Вы выбрали вариант $number.\n\nСкажите разработчику: "Оставь вариант $number"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
