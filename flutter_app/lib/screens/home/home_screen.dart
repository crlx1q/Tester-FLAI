import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import '../../providers/user_provider.dart';
import '../../providers/limits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';
import '../../utils/image_helper.dart';
import '../../models/food_model.dart';
import '../../models/favorite_food_model.dart';
import '../chat/chat_screen.dart';
import '../../widgets/voice_recording_dialog.dart';
import '../../widgets/usage_limit_badge.dart';
import '../../widgets/animated_fire.dart';
import '../../widgets/ai_advice_card.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  DailySummary? _summary;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _showFab = true;
  final ScrollController _scrollController = ScrollController();
  int _analysisProgress = 0;
  String _analysisStatus = '';
  String? _analyzingImagePath;
  final ImagePicker _picker = ImagePicker();
  int _waterAmount = 0; // мл
  Timer? _progressTimer;
  
  int get _waterTarget {
    final userProvider = context.read<UserProvider>();
    return userProvider.user?.waterTarget ?? 1700;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadWaterAmount();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_showFab) setState(() => _showFab = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_showFab) setState(() => _showFab = true);
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _addWater() {
    setState(() {
      _waterAmount += 100;
      if (_waterAmount > _waterTarget) {
        _waterAmount = _waterTarget;
      }
    });
    _saveWaterAmount();
  }

  Future<void> _loadWaterAmount() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    try {
      // Загружаем данные с сервера
      final result = await ApiHelper.getWaterIntake(dateKey);
      
      if (result['success'] && result['waterIntake'] != null) {
        final amount = result['waterIntake']['amount'] ?? 0;
        setState(() => _waterAmount = amount);
        
        // Сохраняем в локальное хранилище для оффлайн режима
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('water_$dateKey', amount);
      } else {
        setState(() => _waterAmount = 0);
      }
    } catch (e) {
      // Если ошибка сети, загружаем из локального хранилища
      print('Ошибка загрузки воды с сервера: $e');
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('water_$dateKey');
      setState(() => _waterAmount = saved ?? 0);
    }
  }

  Future<void> _saveWaterAmount() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // Сохраняем локально сразу для быстрого отклика UI
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_$dateKey', _waterAmount);
    
    try {
      // Синхронизируем с сервером
      final result = await ApiHelper.saveWaterIntake(dateKey, _waterAmount);
      
      if (result['success']) {
        print('✅ Вода синхронизирована с сервером: $_waterAmount мл');
      } else {
        print('⚠️ Не удалось синхронизировать воду с сервером');
      }
    } catch (e) {
      print('❌ Ошибка синхронизации воды: $e');
      // Данные остаются в локальном хранилище
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiHelper.getDailySummary(date: _selectedDate);
      
      if (result['success']) {
        setState(() {
          _summary = DailySummary.fromJson(result['data']);
        });
      } else {
        print('Ошибка загрузки данных: ${result['message']}');
        _showError('Не удалось загрузить данные');
      }
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      _showError('Ошибка загрузки данных');
    }
    
    setState(() => _isLoading = false);
    await _loadWaterAmount();
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadData();
    _loadWaterAmount();
  }

  void _nextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = tomorrow;
      });
      _loadData();
      _loadWaterAmount();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Доброй ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _showAddFoodOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAddOption(
                  icon: Icons.star,
                  label: 'Избранное',
                  color: const Color(0xFFFFA726),
                  onTap: () => Navigator.pop(context, 'favorite'),
                ),
                _buildAddOption(
                  icon: Icons.mic,
                  label: 'Запись голосом',
                  color: const Color(0xFF66BB6A),
                  onTap: () => Navigator.pop(context, 'voice'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAddOption(
                  icon: Icons.edit,
                  label: 'Описать блюдо',
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.pop(context, 'describe'),
                ),
                _buildAddOption(
                  icon: Icons.camera_alt,
                  label: 'Скан еды',
                  color: const Color(0xFFEF5350),
                  onTap: () => Navigator.pop(context, 'scan'),
                ),
              ],
            ),
          ],
            ),
          ),
        ),
      ),
    );

    if (option == null) return;

    switch (option) {
      case 'scan':
        await _scanFood();
        break;
      case 'favorite':
        _showFavorites();
        break;
      case 'voice':
        await _recordVoice();
        break;
      case 'describe':
        await _describeFood();
        break;
    }
  }

  Future<void> _showFavorites() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final result = await ApiHelper.getFavoriteFoods();
    Navigator.pop(context); // Закрываем индикатор загрузки
    
    if (!result['success']) {
      _showError(result['message']);
      return;
    }
    
    final List<FavoriteFoodModel> favorites = (result['favoriteFoods'] as List)
        .map((f) => FavoriteFoodModel.fromJson(f))
        .toList();
    
    if (!mounted) return;
    
    if (favorites.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Избранные блюда'),
          content: const Text('У вас пока нет избранных блюд.\n\nДобавляйте блюда в избранное, чтобы быстро их добавлять!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Показываем список избранных блюд
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFavoritesSheet(favorites),
    );
  }
  
  Widget _buildFavoritesSheet(List<FavoriteFoodModel> favorites) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Хендлер
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFA726), size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Избранные блюда',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Список избранных
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return _buildFavoriteItem(favorite);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFavoriteItem(FavoriteFoodModel favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Эмодзи
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[100]!, Colors.orange[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getFoodEmoji(favorite.name),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${favorite.calories} ккал • Б: ${favorite.macros.protein.toStringAsFixed(favorite.macros.protein % 1 == 0 ? 0 : 1)}г Ж: ${favorite.macros.fat.toStringAsFixed(favorite.macros.fat % 1 == 0 ? 0 : 1)}г У: ${favorite.macros.carbs.toStringAsFixed(favorite.macros.carbs % 1 == 0 ? 0 : 1)}г',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          
          // Кнопка удалить из избранного (звездочка)
          IconButton(
            icon: const Icon(Icons.star, color: Color(0xFFFFA726)),
            onPressed: () async {
              await _removeFavoriteFood(favorite.id);
            },
            tooltip: 'Удалить из избранного',
          ),
          
          // Кнопка добавить
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF66BB6A)),
            onPressed: () async {
              Navigator.pop(context); // Закрываем sheet
              await _addFavoriteToDiary(favorite.id);
            },
            tooltip: 'Добавить в дневник',
          ),
        ],
      ),
    );
  }
  
  Future<void> _removeFavoriteFood(String favoriteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из избранного?'),
        content: const Text('Блюдо будет удалено из списка избранных.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final result = await ApiHelper.removeFavoriteFood(favoriteId);
    Navigator.pop(context); // Закрываем индикатор
    
    if (result['success']) {
      _showSuccess('Блюдо удалено из избранного');
      // Обновляем список избранных
      Navigator.pop(context); // Закрываем sheet
      _showFavorites(); // Открываем заново с обновленным списком
    } else {
      _showError(result['message']);
    }
  }
  
  Future<void> _addFavoriteToDiary(String favoriteId) async {
    final result = await ApiHelper.addFavoriteToDiary(favoriteId);
    
    if (result['success']) {
      _showSuccess('Блюдо добавлено в дневник');
      _loadData(); // Перезагружаем данные дневника
    } else {
      _showError(result['message']);
    }
  }

  Future<void> _recordVoice() async {
    // Показываем диалог записи голоса
    await showDialog(
      context: context,
      builder: (context) => VoiceRecordingDialog(
        onTextRecognized: (text) async {
          // Показываем индикатор загрузки
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI анализирует блюдо...'),
                    ],
                  ),
                ),
              ),
            ),
          );
          
          // Анализируем через AI
          final result = await ApiHelper.analyzeFoodDescription(text);
          
          Navigator.pop(context); // Закрываем индикатор
          
          if (result['success']) {
            _showSuccess('Блюдо "${result['analysis']['name']}" добавлено!');
            await context.read<UserProvider>().loadProfile();
            
            // Обновляем лимиты
            final authProvider = context.read<AuthProvider>();
            final token = await authProvider.getToken();
            if (token != null) {
              await context.read<LimitsProvider>().loadLimits(
                token,
                ApiHelper.baseUrl,
              );
            }
            
            _loadData(); // Обновляем дневник
          } else {
            _showError(result['message'] ?? 'Ошибка анализа');
          }
        },
      ),
    );
  }

  Future<void> _describeFood() async {
    final TextEditingController descriptionController = TextEditingController();
    
    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.purple),
            SizedBox(width: 8),
            Text('Описать блюдо'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Опишите блюдо своими словами, а AI определит калории и БЖУ',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание блюда',
                hintText: 'Например: Овсяная каша на молоке с бананом и медом',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, descriptionController.text),
            child: const Text('Анализировать'),
          ),
        ],
      ),
    );

    if (description != null && description.isNotEmpty) {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2937)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('AI анализирует блюдо...'),
              ],
            ),
          ),
        ),
      );
      
      // Анализируем через AI
      final result = await ApiHelper.analyzeFoodDescription(description);
      
      Navigator.pop(context); // Закрываем индикатор
      
      if (result['success']) {
        _showSuccess('Блюдо "${result['analysis']['name']}" добавлено!');
        await context.read<UserProvider>().loadProfile();
        
        // Обновляем лимиты
        final authProvider = context.read<AuthProvider>();
        final token = await authProvider.getToken();
        if (token != null) {
          await context.read<LimitsProvider>().loadLimits(
            token,
            ApiHelper.baseUrl,
          );
        }
        
        _loadData(); // Обновляем дневник
      } else {
        _showError(result['message'] ?? 'Ошибка анализа');
      }
    }
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startProgressAnimation() {
    // Отменяем предыдущий таймер, если он есть
    _progressTimer?.cancel();
    
    // Общая длительность анимации - 10 секунд
    const totalDuration = Duration(seconds: 10);
    // Обновляем каждые 100 миллисекунд
    const updateInterval = Duration(milliseconds: 100);
    // Общее количество обновлений
    final totalUpdates = totalDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    int currentUpdate = 0;
    
    // Список статусов для показа во время анализа
    final statuses = [
      'Отделяем ингредиенты...',
      'Анализируем состав...',
      'Определяем калории...',
      'Подсчитываем макронутриенты...',
      'Почти готово...',
    ];
    
    _progressTimer = Timer.periodic(updateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      currentUpdate++;
      
      // Вычисляем прогресс (от 0 до 99)
      final progress = (currentUpdate / totalUpdates * 99).round();
      
      // Меняем статус в зависимости от прогресса
      String status = statuses[0];
      if (progress >= 20 && progress < 40) {
        status = statuses[1];
      } else if (progress >= 40 && progress < 60) {
        status = statuses[2];
      } else if (progress >= 60 && progress < 80) {
        status = statuses[3];
      } else if (progress >= 80) {
        status = statuses[4];
      }
      
      setState(() {
        _analysisProgress = progress.clamp(0, 99);
        _analysisStatus = status;
      });
      
      // Останавливаем таймер когда достигли 99%
      if (currentUpdate >= totalUpdates) {
        timer.cancel();
      }
    });
  }

  Future<void> _scanFood() async {
    // Get limits to show usage
    final limitsProvider = context.read<LimitsProvider>();
    final limits = limitsProvider.limits;
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выберите источник'),
            if (limits != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.photo_camera,
                    size: 16,
                    color: limits.photos.remaining > 0 
                        ? Colors.orange 
                        : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${limits.photos.remaining}/${limits.photos.max}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: limits.photos.remaining > 0 
                          ? Colors.orange 
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (limits != null && limits.photos.remaining <= 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Лимит фото исчерпан. Обновите до PRO для продолжения.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              enabled: limits?.photos.remaining != 0,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              enabled: limits?.photos.remaining != 0,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image == null) return;
    
    // Показываем анализ прямо в списке
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0;
      _analysisStatus = 'Отделяем ингредиенты...';
      _analyzingImagePath = image.path;
    });
    
    // Запускаем плавную анимацию прогресса от 0% до 99% за 10 секунд
    _startProgressAnimation();
    
    // Отправляем на анализ
    final result = await ApiHelper.analyzeFood(File(image.path));
    
    // Останавливаем таймер и показываем 100%
    _progressTimer?.cancel();
    
    if (mounted) {
      setState(() {
        _analysisProgress = 100;
        _analysisStatus = 'Готово!';
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analyzingImagePath = null;
      });
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Блюдо успешно добавлено!'),
            backgroundColor: Colors.green,
          ),
        );
        // Обновляем данные и профиль пользователя (для streak)
        await context.read<UserProvider>().loadProfile();
        
        // Обновляем лимиты
        final authProvider = context.read<AuthProvider>();
        final token = await authProvider.getToken();
        if (token != null) {
          await context.read<LimitsProvider>().loadLimits(
            token,
            ApiHelper.baseUrl,
          );
        }
        
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ошибка анализа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMonthlyStats(BuildContext context) async {
    // Показываем диалог с загрузкой
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Загружаем активные дни с сервера
    final now = DateTime.now();
    final result = await ApiHelper.getMonthlyActiveDays(
      year: now.year,
      month: now.month,
    );
    
    // Закрываем индикатор загрузки
    if (context.mounted) Navigator.pop(context);
    
    // Парсим активные дни
    final activeDays = <DateTime>{};
    if (result['success'] && result['data'] != null) {
      final daysData = result['data'] as List<dynamic>;
      for (var dateStr in daysData) {
        try {
          activeDays.add(DateTime.parse(dateStr));
        } catch (e) {
          // Пропускаем неверные даты
        }
      }
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Заголовок
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Активность',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Календарь
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: DateTime.now(),
                locale: 'ru_RU',
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, activeDays);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, activeDays, isToday: true);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, activeDays, isOutside: true);
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Статистика
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('Текущая серия', '${context.read<UserProvider>().currentStreak}', Icons.local_fire_department),
                  _buildStatBadge('Рекорд', '${context.read<UserProvider>().user?.maxStreak ?? 0}', Icons.emoji_events),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<List<DateTime>> _getStreaks(Set<DateTime> activeDays) {
    final sortedDays = activeDays.toList()..sort();
    final streaks = <List<DateTime>>[];
    var currentStreak = <DateTime>[];
    
    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      
      if (currentStreak.isEmpty) {
        currentStreak.add(day);
      } else {
        final lastDay = currentStreak.last;
        final daysDiff = day.difference(lastDay).inDays;
        
        if (daysDiff == 1) {
          // Продолжаем серию
          currentStreak.add(day);
        } else {
          // Прерываем серию
          if (currentStreak.length > 1) {
            streaks.add(List.from(currentStreak));
          }
          currentStreak = [day];
        }
      }
    }
    
    // Добавляем последнюю серию
    if (currentStreak.length > 1) {
      streaks.add(currentStreak);
    }
    
    return streaks;
  }

  Widget _buildCalendarDay(DateTime day, Set<DateTime> activeDays, {bool isToday = false, bool isOutside = false}) {
    final now = DateTime.now();
    // Normalize dates to compare only date parts (ignore time)
    final today = DateTime(now.year, now.month, now.day);
    final dayNormalized = DateTime(day.year, day.month, day.day);
    
    final isPast = dayNormalized.isBefore(today);
    final isFuture = dayNormalized.isAfter(today);
    final isActive = activeDays.any((d) => 
      d.year == day.year && d.month == day.month && d.day == day.day
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Проверяем, является ли день частью серии
    final streaks = _getStreaks(activeDays);
    final isInStreak = streaks.any((streak) => 
      streak.any((d) => d.year == day.year && d.month == day.month && d.day == day.day)
    );
    
    // Определяем позицию в серии для создания полоски
    String? streakPosition;
    if (isInStreak) {
      for (final streak in streaks) {
        if (streak.any((d) => d.year == day.year && d.month == day.month && d.day == day.day)) {
          final index = streak.indexWhere((d) => d.year == day.year && d.month == day.month && d.day == day.day);
          if (index == 0) {
            streakPosition = 'start';
          } else if (index == streak.length - 1) {
            streakPosition = 'end';
          } else {
            streakPosition = 'middle';
          }
          break;
        }
      }
    }
    
    Color? bgColor;
    Color? textColor;
    
    if (isOutside) {
      // Дни вне текущего месяца - просто цифры
      textColor = isDark ? Colors.grey[600] : Colors.grey[300];
    } else if (isFuture) {
      // Будущие дни - просто цифры
      textColor = isDark ? Colors.grey[500] : Colors.grey[400];
    } else if (isToday) {
      // Сегодняшний день (Duolingo-style):
      // - Серый круг если еще не активен
      // - Оранжевый круг если уже есть активность
      if (isActive) {
        bgColor = Colors.orange;
        textColor = Colors.white;
      } else {
        bgColor = Colors.grey[400];
        textColor = Colors.white;
      }
    } else if (isPast) {
      // Прошлые дни:
      // - Оранжевый круг если был активен
      // - Серый круг если не был активен
      if (isActive) {
        bgColor = Colors.orange;
        textColor = Colors.white;
      } else {
        bgColor = Colors.grey[400];
        textColor = Colors.white;
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        // Добавляем полоску для серий
        border: isInStreak ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon) {
    final isFireIcon = icon == Icons.local_fire_department;
    return Column(
      children: [
        isFireIcon
            ? const AnimatedFire(size: 24, isActive: true)
            : Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Фото с прогрессом
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_analyzingImagePath != null)
                  Image.file(
                    File(_analyzingImagePath!),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: _analysisProgress / 100,
                          strokeWidth: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      Text(
                        '$_analysisProgress%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Текст
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _analysisStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Мы сообщим, когда все будет готово',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting + Streak row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isToday ? 'Ваша сводка' : 'История',
                                  style: Theme.of(context).textTheme.displaySmall,
                                ),
                              ],
                            ),
                          ),
                          // Notification bell
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_outlined, size: 20),
                            ),
                          ),
                          // Streak indicator
                          GestureDetector(
                            onTap: () => _showMonthlyStats(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: userProvider.streakStatus == 'active'
                                    ? AppTheme.primaryGradient
                                    : null,
                                color: userProvider.streakStatus != 'active'
                                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                                    : null,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedFire(
                                    size: 18,
                                    isActive: userProvider.streakStatus == 'active',
                                    inactiveColor: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${userProvider.currentStreak}',
                                    style: TextStyle(
                                      color: userProvider.streakStatus == 'active' ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Date navigation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _previousDay,
                              icon: const Icon(Icons.chevron_left_rounded, size: 24),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              _isToday
                                  ? 'Сегодня'
                                  : DateFormat('d MMMM', 'ru').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: _isToday ? null : _nextDay,
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                size: 24,
                                color: _isToday ? Theme.of(context).colorScheme.outline : null,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Calorie Chart with Macros
                      if (_summary != null) _buildCalorieChart(),
                      
                      const SizedBox(height: 16),
                      
                      // Water tracker
                      if (_summary != null) _buildWaterCard(),
                      
                      const SizedBox(height: 16),
                      
                      // AI Advice Card
                      if (_isToday && _summary != null)
                        const AiAdviceCard(),
                      
                      const SizedBox(height: 24),
                      
                      // Food Diary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Дневник питания',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Карточка анализа (если идет)
                      if (_isAnalyzing) _buildAnalyzingCard(),
                      
                      if (_summary != null && _summary!.foods.isNotEmpty)
                        ..._summary!.foods.map((food) => _buildFoodItem(food))
                      else if (!_isAnalyzing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Пока нет записей.\nДобавьте своё первое блюдо!',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: _isToday && _showFab && _summary != null
          ? Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _showAddFoodOptions,
                backgroundColor: Colors.transparent,
                elevation: 0,
                highlightElevation: 0,
                icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                label: const Text(
                  'Добавить приём пищи',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCalorieChart() {
    final consumed = _summary!.totalCalories;
    final target = _summary!.targetCalories;
    final remaining = (target - consumed).clamp(0, target);
    final percentage = (consumed / target).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          // Ring gauge
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _CircularRingPainter(
                    progress: percentage,
                    isDark: isDark,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Осталось',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: Text(
                        '$remaining',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      'ккал',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Consumed / Target summary
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$consumed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                ' / $target ккал',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Макросы с прогресс-барами (иерархия по цели)
          Builder(builder: (context) {
            final goal = context.read<UserProvider>().user?.goal;
            // gain_muscle / gain_weight → Белки и Углеводы главные
            // lose_weight → Белки главный
            // maintain / null → все равны
            final proteinPrimary = goal == 'gain_muscle' || goal == 'gain_weight' || goal == 'lose_weight';
            final carbsPrimary = goal == 'gain_muscle' || goal == 'gain_weight';
            final fatPrimary = false;
            return Row(
              children: [
                Expanded(
                  child: _buildMacroCard(
                    color: const Color(0xFFEF5350),
                    label: 'Белки',
                    consumed: _summary!.consumedMacros.protein,
                    target: _summary!.targetMacros.protein,
                    isPrimary: proteinPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMacroCard(
                    color: const Color(0xFFFFA726),
                    label: 'Углеводы',
                    consumed: _summary!.consumedMacros.carbs,
                    target: _summary!.targetMacros.carbs,
                    isPrimary: carbsPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMacroCard(
                    color: const Color(0xFF42A5F5),
                    label: 'Жиры',
                    consumed: _summary!.consumedMacros.fat,
                    target: _summary!.targetMacros.fat,
                    isPrimary: fatPrimary,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required Color color,
    required String label,
    required double consumed,
    required double target,
    bool isPrimary = false,
  }) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final barHeight = isPrimary ? 10.0 : 5.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: isPrimary ? 10 : 8,
              height: isPrimary ? 10 : 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isPrimary
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isPrimary ? 12 : 11,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                  color: isPrimary
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A))
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
            ),
            if (isPrimary)
              Icon(Icons.star_rounded, size: 12, color: color.withOpacity(0.7)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(isPrimary ? 5 : 3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: barHeight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${consumed.toStringAsFixed(consumed % 1 == 0 ? 0 : 1)} / ${target.toStringAsFixed(target % 1 == 0 ? 0 : 1)}г',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWaterCard() {
    final waterProgress = (_waterAmount / _waterTarget).clamp(0.0, 1.0);
    final isDone = _waterAmount >= _waterTarget;
    
    return GestureDetector(
      onTap: _isToday ? _addWater : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF22C55E).withOpacity(0.12) : const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.water_drop_rounded,
                color: isDone ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вода',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: waterProgress,
                      backgroundColor: (isDone ? const Color(0xFF22C55E) : const Color(0xFF3B82F6)).withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(isDone ? const Color(0xFF22C55E) : const Color(0xFF3B82F6)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '$_waterAmount / $_waterTarget мл',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            if (_isToday) ...[
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(FoodModel food) {
    return GestureDetector(
      onTap: () => _showFoodDetails(food),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            // Image or Emoji
            SizedBox(
              width: 60,
              height: 60,
              child: food.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageHelper.buildImage(
                        food.imageUrl,
                        fit: BoxFit.cover,
                        // НЕ используем cacheWidth/cacheHeight - они искажают пропорции!
                        // BoxFit.cover сам обрежет по центру
                        errorWidget: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange[100]!, Colors.orange[50]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _getFoodEmoji(food.name),
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[100]!, Colors.orange[50]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getFoodEmoji(food.name),
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        food.mealType,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Text(' • '),
                      Text(
                        DateFormat('HH:mm').format(food.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Calories
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${food.calories} ккал',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFoodEmoji(String foodName) {
    // Проверяем есть ли эмодзи в начале названия (от AI)
    if (foodName.isNotEmpty) {
      final firstChar = foodName.runes.first;
      // Эмодзи находятся в диапазоне Unicode 0x1F300-0x1F9FF
      if (firstChar >= 0x1F300 && firstChar <= 0x1F9FF) {
        return String.fromCharCode(firstChar);
      }
    }
    
    // Если эмодзи нет, определяем по ключевым словам
    final name = foodName.toLowerCase();
    
    // Фрукты
    if (name.contains('мандарин') || name.contains('апельсин')) return '🍊';
    if (name.contains('яблок')) return '🍎';
    if (name.contains('банан')) return '🍌';
    if (name.contains('виноград')) return '🍇';
    if (name.contains('арбуз')) return '🍉';
    if (name.contains('клубник')) return '🍓';
    if (name.contains('киви')) return '🥝';
    if (name.contains('ананас')) return '🍍';
    if (name.contains('черри') || name.contains('вишн')) return '🍒';
    if (name.contains('лимон')) return '🍋';
    
    // Овощи
    if (name.contains('морковь')) return '🥕';
    if (name.contains('огурец') || name.contains('огур')) return '🥒';
    if (name.contains('помидор') || name.contains('томат')) return '🍅';
    if (name.contains('брокколи')) return '🥦';
    if (name.contains('картофел') || name.contains('картошк')) return '🥔';
    
    // Хлеб и выпечка
    if (name.contains('хлеб') || name.contains('булк')) return '🍞';
    if (name.contains('круассан')) return '🥐';
    if (name.contains('бублик') || name.contains('бейгл')) return '🥯';
    if (name.contains('кекс') || name.contains('маффин')) return '🧁';
    
    // Молочное и яйца
    if (name.contains('яйц')) return '🥚';
    if (name.contains('молок') || name.contains('йогурт')) return '🥛';
    if (name.contains('сыр')) return '🧀';
    
    // Мясо и птица
    if (name.contains('курица') || name.contains('цыпл')) return '🍗';
    if (name.contains('мясо') || name.contains('стейк') || name.contains('говяд')) return '🥩';
    if (name.contains('бекон')) return '🥓';
    if (name.contains('колбас') || name.contains('сосиск')) return '🌭';
    
    // Рыба и морепродукты
    if (name.contains('рыб')) return '🐟';
    if (name.contains('суши') || name.contains('роллы')) return '🍣';
    if (name.contains('креветк')) return '🍤';
    
    // Фастфуд
    if (name.contains('пицц')) return '🍕';
    if (name.contains('бургер')) return '🍔';
    if (name.contains('шаурм') || name.contains('шаверм')) return '🌯';
    if (name.contains('тако')) return '🌮';
    if (name.contains('буррито')) return '🌯';
    if (name.contains('хот-дог') || name.contains('хотдог')) return '🌭';
    if (name.contains('фри') || name.contains('картофель фри')) return '🍟';
    
    // Основные блюда
    if (name.contains('салат')) return '🥗';
    if (name.contains('паста') || name.contains('спагетти') || name.contains('макарон')) return '🍝';
    if (name.contains('рис')) return '🍚';
    if (name.contains('суп') || name.contains('борщ')) return '🍲';
    if (name.contains('плов')) return '🍛';
    if (name.contains('карри')) return '🍛';
    if (name.contains('рамен') || name.contains('лапш')) return '🍜';
    
    // Десерты
    if (name.contains('торт') || name.contains('пирож')) return '🍰';
    if (name.contains('морожен')) return '🍦';
    if (name.contains('шоколад')) return '🍫';
    if (name.contains('печень') || name.contains('кук')) return '🍪';
    if (name.contains('пончик') || name.contains('донат')) return '🍩';
    if (name.contains('конфет')) return '🍬';
    
    // Напитки
    if (name.contains('кофе')) return '☕';
    if (name.contains('чай')) return '🍵';
    if (name.contains('сок')) return '🧃';
    if (name.contains('вод')) return '💧';
    if (name.contains('смузи')) return '🥤';
    
    // Орехи и снеки
    if (name.contains('орех') || name.contains('арахис')) return '🥜';
    if (name.contains('попкорн')) return '🍿';
    if (name.contains('чипс')) return '🥨';
    
    return '🍽️'; // По умолчанию
  }

  void _showFoodDetails(FoodModel food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFoodDetailsSheet(food),
    );
  }

  Widget _buildFoodDetailsSheet(FoodModel food) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Хендлер
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, size: 20, color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Контент
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фото или эмодзи
                  if (food.imageUrl != null)
                    Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageHelper.buildImage(
                          food.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: Theme.of(context).brightness == Brightness.dark
                                  ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                                  : [Colors.orange[100]!, Colors.orange[50]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                _getFoodEmoji(food.name),
                                style: const TextStyle(fontSize: 80),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: Theme.of(context).brightness == Brightness.dark
                            ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                            : [Colors.orange[100]!, Colors.orange[50]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _getFoodEmoji(food.name),
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Название
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.pop(context);
                          _editFoodName(food);
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    '${DateFormat('d MMMM y', 'ru').format(food.timestamp)} г. в ${DateFormat('HH:mm').format(food.timestamp)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Калории
                  Text(
                    'Калории и нутриенты',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF374151) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          '${food.calories}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          ' ккал',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Макросы
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailMacro(
                          Icons.grain,
                          'Углеводы',
                          food.macros.carbs,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailMacro(
                          Icons.fastfood,
                          'Белки',
                          food.macros.protein,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailMacro(
                          Icons.opacity,
                          'Жиры',
                          food.macros.fat,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Оценка полезности
                  Text(
                    'Оценка полезности',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildHealthScoreBar(food.healthScore), // AI заполняет от 0 до 100
                ],
              ),
            ),
          ),
          
          // Кнопки действий
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Спросить
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Спросить',
                    onTap: () {
                      Navigator.pop(context);
                      _askAboutFood(food);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Избранное
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.star_border,
                    label: 'Избранное',
                    onTap: () async {
                      Navigator.pop(context);
                      await _addFoodToFavorites(food);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Удалить
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Удалить',
                    isDelete: true,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteFood(food);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMacro(IconData icon, String label, double value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} г',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDelete = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white : Colors.black87,
              size: 24,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Функция для перехода к чату с контекстом блюда
  void _askAboutFood(FoodModel food) {
    // Переходим на экран чата с прикрепленным блюдом
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(attachedFood: food),
      ),
    );
  }
  
  // Функция для добавления блюда в избранное
  Future<void> _addFoodToFavorites(FoodModel food) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final result = await ApiHelper.addToFavorites(food.id);
    Navigator.pop(context); // Закрываем индикатор
    
    if (result['success']) {
      _showSuccess('Блюдо "${food.name}" добавлено в избранное');
    } else {
      _showError(result['message']);
    }
  }
  
  // Функция для редактирования названия блюда
  Future<void> _editFoodName(FoodModel food) async {
    final controller = TextEditingController(text: food.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить блюдо'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Введите новое название блюда, и AI пересчитает калории и БЖУ:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название блюда',
                hintText: 'Например: Греческий салат',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName != food.name) {
      await _updateFoodWithAI(food, newName);
    }
  }
  
  // Функция для обновления блюда через AI
  Future<void> _updateFoodWithAI(FoodModel food, String newName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2937)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI анализирует блюдо...'),
            ],
          ),
        ),
      ),
    );
    
    Map<String, dynamic> analysisResult;
    bool wasUpdatedOnServer = false; // Флаг: было ли блюдо обновлено на сервере
    
    // Если у блюда есть фото, отправляем фото + название для более точного анализа
    if (food.imageUrl != null && food.imageUrl!.isNotEmpty) {
      try {
        String base64Image;
        
        // Проверяем, это уже base64 или нужно загрузить с сервера
        if (food.imageUrl!.startsWith('data:image')) {
          // Изображение уже в формате base64
          print('✅ Изображение уже в base64 формате');
          base64Image = food.imageUrl!;
        } else {
          // Загружаем изображение с сервера
          final imageUrl = food.imageUrl!.startsWith('http')
              ? food.imageUrl!
              : '${ApiHelper.mediaUrl}${food.imageUrl}';
          
          print('📥 Загрузка изображения для редактирования: $imageUrl');
          final response = await http.get(Uri.parse(imageUrl));
          print('📥 Статус загрузки: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            // Конвертируем в base64
            base64Image = 'data:image/jpeg;base64,${base64Encode(response.bodyBytes)}';
            print('✅ Изображение загружено, размер: ${response.bodyBytes.length} байт');
          } else {
            // Если не удалось загрузить фото, анализируем только по названию
            print('⚠️ Не удалось загрузить фото (статус ${response.statusCode}), используем только текст');
            analysisResult = await ApiHelper.analyzeFoodDescriptionOnly(newName);
            Navigator.pop(context);
            
            if (analysisResult['success']) {
              final analysis = analysisResult['analysis'];
              final updateResult = await ApiHelper.updateFood(
                food.id,
                {
                  'name': '${analysis['emoji']} ${analysis['name']}',
                  'calories': analysis['calories'],
                  'macros': analysis['macros'],
                  'healthScore': analysis.containsKey('healthScore') ? analysis['healthScore'] : 50,
                },
              );
              
              if (updateResult['success']) {
                _showSuccess('Блюдо обновлено! Новые данные от AI');
                setState(() {});
                await _loadData();
              } else {
                _showError(updateResult['message']);
              }
            } else {
              _showError('Не удалось проанализировать блюдо');
            }
            return;
          }
        }
        
        // Отправляем на анализ с фото и новым названием
        print('🔄 Вызываем updateFoodWithImage...');
        analysisResult = await ApiHelper.updateFoodWithImage(
          food.id,
          newName,
          base64Image,
        );
        wasUpdatedOnServer = true; // Блюдо обновлено на сервере!
        print('✅ updateFoodWithImage выполнен успешно');
      } catch (e) {
        print('❌ Ошибка при обработке изображения: $e');
        print('❌ StackTrace: ${StackTrace.current}');
        // Если ошибка, анализируем только по названию
        analysisResult = await ApiHelper.analyzeFoodDescriptionOnly(newName);
      }
    } else {
      // Если фото нет, анализируем только по названию
      analysisResult = await ApiHelper.analyzeFoodDescriptionOnly(newName);
    }
    
    Navigator.pop(context); // Закрываем индикатор
    
    if (analysisResult['success']) {
      // Если использовали updateFoodWithImage, блюдо уже обновлено на сервере
      if (wasUpdatedOnServer) {
        _showSuccess('Блюдо обновлено! Новые данные от AI с учетом фото');
      } else {
        // Иначе обновляем вручную
        final analysis = analysisResult['analysis'];
        
        final updateResult = await ApiHelper.updateFood(
          food.id,
          {
            'name': '${analysis['emoji']} ${analysis['name']}',
            'calories': analysis['calories'],
            'macros': analysis['macros'],
            'healthScore': analysis.containsKey('healthScore') ? analysis['healthScore'] : 50,
          },
        );
        
        if (updateResult['success']) {
          _showSuccess('Блюдо обновлено! Новые данные от AI');
        } else {
          _showError(updateResult['message']);
        }
      }
      
      // Принудительно обновляем UI
      setState(() {});
      await _loadData(); // Перезагружаем данные
    } else {
      _showError('Не удалось проанализировать блюдо');
    }
  }
  
  // Функция для подтверждения удаления блюда
  Future<void> _confirmDeleteFood(FoodModel food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить блюдо?'),
        content: Text('Вы уверены, что хотите удалить "${food.name}" из дневника?\n\nЭто действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteFood(food);
    }
  }
  
  // Функция для удаления блюда
  Future<void> _deleteFood(FoodModel food) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final result = await ApiHelper.deleteFood(food.id);
    Navigator.pop(context); // Закрываем индикатор
    
    if (result['success']) {
      _showSuccess('Блюдо "${food.name}" удалено');
      _loadData(); // Перезагружаем данные дневника
    } else {
      _showError(result['message']);
    }
  }
  
  // Вспомогательные функции для показа сообщений
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF66BB6A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHealthScoreBar(int score) {
    final percentage = (score / 100).clamp(0.0, 1.0);
    
    // Определяем статус и цвет на основе оценки
    String status;
    Color statusColor;
    Color badgeColor;
    
    if (score <= 30) {
      status = 'Вредная еда';
      statusColor = const Color(0xFFEF5350); // Красный
      badgeColor = const Color(0xFFEF5350);
    } else if (score <= 50) {
      status = 'Не очень полезно';
      statusColor = const Color(0xFFFF9800); // Оранжевый
      badgeColor = const Color(0xFFFF9800);
    } else if (score <= 70) {
      status = 'Средняя польза';
      statusColor = const Color(0xFFFFC107); // Желтый
      badgeColor = const Color(0xFFFFC107);
    } else if (score <= 85) {
      status = 'Полезная еда';
      statusColor = const Color(0xFF66BB6A); // Зеленый
      badgeColor = const Color(0xFF66BB6A);
    } else {
      status = 'Очень полезно!';
      statusColor = const Color(0xFF4CAF50); // Темно-зеленый
      badgeColor = const Color(0xFF4CAF50);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Stack(
              children: [
                // Фиксированный градиент (фон)
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEF5350), // Красный
                        Color(0xFFFF9800), // Оранжевый
                        Color(0xFFFFC107), // Желтый
                        Color(0xFF66BB6A), // Зеленый
                        Color(0xFF4CAF50), // Темно-зеленый
                      ],
                      stops: [0.0, 0.3, 0.5, 0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Белая метка текущей позиции
                Positioned(
                  left: percentage * MediaQuery.of(context).size.width * 0.85 - 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Full circle ring gauge painter (Yazio/Samsung Health style)
class _CircularRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _CircularRingPainter({
    required this.progress,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeWidth = 14.0;
    
    // Background ring
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring with gradient
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweepAngle = 2 * math.pi * progress;
      
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: const [
          Color(0xFFFF8A5B),
          Color(0xFFFF5A82),
        ],
        transform: const GradientRotation(-math.pi / 2),
      );
      
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
      
      // Glow at the end of the progress arc
      final endAngle = -math.pi / 2 + sweepAngle;
      final endX = center.dx + radius * math.cos(endAngle);
      final endY = center.dy + radius * math.sin(endAngle);
      
      final glowPaint = Paint()
        ..color = const Color(0xFFFF5A82).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(Offset(endX, endY), strokeWidth / 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
