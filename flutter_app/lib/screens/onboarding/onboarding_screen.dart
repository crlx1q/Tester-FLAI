import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import 'ai_plan_loading_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;
  
  String? _selectedGoal;
  String? _selectedGender;
  int? _age;
  int? _height;
  double? _weight;
  int _activityLevel = 2;
  final List<String> _selectedAllergies = [];
  
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final userProvider = context.read<UserProvider>();
    
    final data = {
      'goal': _selectedGoal,
      'gender': _selectedGender,
      'age': _age,
      'height': _height,
      'weight': _weight,
      'activityLevel': _activityLevel == 1 ? 'sedentary' : _activityLevel == 2 ? 'moderate' : 'active',
      'allergies': _selectedAllergies,
    };
    
    // Переходим на экран загрузки AI
    if (mounted) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => AIPlanLoadingScreen(
            onComplete: () => userProvider.completeOnboarding(data),
          ),
        ),
      );
      
      // После возврата с экрана результата
      if (result != null && result['success'] == true) {
        widget.onComplete();
      } else if (result != null && result['success'] == false) {
        // Показываем ошибку
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Ошибка завершения регистрации')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryOrange),
              ),
              
              const SizedBox(height: 24),
              
              // Steps
              Expanded(
                child: _buildStep(),
              ),
              
              // Navigation buttons
              if (_currentStep < _totalSteps - 1)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _nextStep : null,
                    child: const Text('Далее'),
                  ),
                ),
              
              if (_currentStep == _totalSteps - 1)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Завершить'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true; // Welcome screen
      case 1:
        return _selectedGoal != null;
      case 2:
        return _selectedGender != null && _age != null && _height != null && _weight != null;
      case 3:
        return true; // Activity & allergies
      case 4:
        return true; // Final
      default:
        return false;
    }
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildGoalStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildActivityStep();
      case 4:
        return _buildFinalStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.restaurant,
            size: 50,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 32),
        
        Text(
          'Добро пожаловать в',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: Text(
            'FoodLens AI',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Ваш личный AI-нутрициолог для здорового питания',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    final goals = [
      {'value': 'lose_weight', 'label': 'Похудеть', 'icon': Icons.trending_down},
      {'value': 'gain_muscle', 'label': 'Набрать массу', 'icon': Icons.fitness_center},
      {'value': 'eat_healthier', 'label': 'Питаться полезнее', 'icon': Icons.favorite},
      {'value': 'maintain_weight', 'label': 'Удерживать вес', 'icon': Icons.balance},
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Какая ваша главная цель?',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        ...goals.map((goal) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedGoal = goal['value'] as String;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedGoal == goal['value']
                      ? AppTheme.accentRed
                      : Colors.grey[300]!,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: _selectedGoal == goal['value']
                    ? AppTheme.accentRed.withOpacity(0.05)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    goal['icon'] as IconData,
                    color: _selectedGoal == goal['value']
                        ? AppTheme.accentRed
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 16),
                  Text(
                    goal['label'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedGoal == goal['value']
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedGoal == goal['value']
                          ? AppTheme.accentRed
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Укажите ваш пол',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'female';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedGender == 'female'
                            ? AppTheme.accentRed
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: _selectedGender == 'female'
                          ? AppTheme.accentRed.withOpacity(0.05)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.female,
                          size: 40,
                          color: _selectedGender == 'female'
                              ? AppTheme.accentRed
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        const Text('Женский'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'male';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedGender == 'male'
                            ? AppTheme.accentRed
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: _selectedGender == 'male'
                          ? AppTheme.accentRed.withOpacity(0.05)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.male,
                          size: 40,
                          color: _selectedGender == 'male'
                              ? AppTheme.accentRed
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        const Text('Мужской'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Возраст, рост и вес',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Возраст (лет)',
              hintText: '25',
            ),
            onChanged: (value) {
              setState(() {
                _age = int.tryParse(value);
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Рост (см)',
              hintText: '175',
            ),
            onChanged: (value) {
              setState(() {
                _height = int.tryParse(value);
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Текущий вес (кг)',
              hintText: '70.5',
            ),
            onChanged: (value) {
              setState(() {
                _weight = double.tryParse(value);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Ваш уровень активности',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          Slider(
            value: _activityLevel.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            label: _activityLevel == 1 ? 'Мало' : _activityLevel == 2 ? 'Умеренно' : 'Активно',
            activeColor: AppTheme.accentRed,
            onChanged: (value) {
              setState(() {
                _activityLevel = value.toInt();
              });
            },
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Мало', style: Theme.of(context).textTheme.bodySmall),
              Text('Умеренно', style: Theme.of(context).textTheme.bodySmall),
              Text('Активно', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          
          const SizedBox(height: 48),
          
          Text(
            'Пищевые ограничения',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          CheckboxListTile(
            title: const Text('Нет глютена'),
            value: _selectedAllergies.contains('gluten'),
            onChanged: (value) {
              setState(() {
                if (value!) {
                  _selectedAllergies.add('gluten');
                } else {
                  _selectedAllergies.remove('gluten');
                }
              });
            },
            activeColor: AppTheme.accentRed,
          ),
          
          CheckboxListTile(
            title: const Text('Нет лактозы'),
            value: _selectedAllergies.contains('lactose'),
            onChanged: (value) {
              setState(() {
                if (value!) {
                  _selectedAllergies.add('lactose');
                } else {
                  _selectedAllergies.remove('lactose');
                }
              });
            },
            activeColor: AppTheme.accentRed,
          ),
          
          CheckboxListTile(
            title: const Text('Вегетарианство'),
            value: _selectedAllergies.contains('vegetarian'),
            onChanged: (value) {
              setState(() {
                if (value!) {
                  _selectedAllergies.add('vegetarian');
                } else {
                  _selectedAllergies.remove('vegetarian');
                }
              });
            },
            activeColor: AppTheme.accentRed,
          ),
        ],
      ),
    );
  }

  Widget _buildFinalStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          size: 100,
          color: Colors.green,
        ),
        
        const SizedBox(height: 32),
        
        Text(
          'Почти готово!',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Наш AI анализирует ваши данные, чтобы создать идеальный план питания.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
