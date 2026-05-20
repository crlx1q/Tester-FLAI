import 'package:flutter/material.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  String? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    final result = await ApiHelper.sendChatMessage(
      'Создай мне детальную сводку за сегодняшний день с анализом моего питания, достижениями и рекомендациями',
    );

    if (result['success']) {
      setState(() {
        _summary = result['response'];
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневная сводка AI'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI анализирует ваш день...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI-анализ вашего дня',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_summary != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        _summary!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Text('Не удалось загрузить сводку'),
                    ),
                ],
              ),
            ),
    );
  }
}
