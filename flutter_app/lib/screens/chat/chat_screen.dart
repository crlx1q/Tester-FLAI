import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';
import '../../utils/image_helper.dart';
import '../../models/food_model.dart';
import '../../providers/limits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/usage_limit_badge.dart';

class ChatScreen extends StatefulWidget {
  final FoodModel? attachedFood;
  
  const ChatScreen({super.key, this.attachedFood});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;
  FoodModel? _attachedFood;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    
    _attachedFood = widget.attachedFood;
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('chat_history');
    
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      setState(() {
        _messages.addAll(
          decoded.map((e) => ChatMessage(
            text: e['text'],
            isUser: e['isUser'],
            timestamp: DateTime.parse(e['timestamp']).toLocal(),
            imagePath: e['imagePath'],
            attachedFood: e['attachedFood'] != null 
                ? FoodModel.fromJson(e['attachedFood'])
                : null,
          )).toList(),
        );
      });
    }
    
    _scrollToBottom();
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _messages.map((e) => {
        'text': e.text,
        'isUser': e.isUser,
        'timestamp': e.timestamp.toUtc().toIso8601String(),
        'imagePath': e.imagePath,
        'attachedFood': e.attachedFood?.toJson(),
      }).toList(),
    );
    await prefs.setString('chat_history', encoded);
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все сообщения будут удалены. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_history');
      
      setState(() {
        _messages.clear();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _messageController.text.trim();
    final imagePath = _selectedImagePath;
    final attachedFood = _attachedFood;
    
    if (text.isEmpty && imagePath == null && attachedFood == null) return;

    // Формируем текст сообщения с контекстом блюда если есть
    String messageText = text;
    
    // Если есть прикрепленное блюдо, всегда добавляем его контекст
    if (attachedFood != null) {
      final foodContext = '\n\nКонтекст блюда:\n- Название: ${attachedFood.name}\n- Калории: ${attachedFood.calories} ккал\n- Белки: ${attachedFood.macros.protein}г\n- Жиры: ${attachedFood.macros.fat}г\n- Углеводы: ${attachedFood.macros.carbs}г';
      
      if (text.isEmpty) {
        messageText = 'Расскажи мне об этом блюде$foodContext';
      } else {
        messageText = '$text$foodContext';
      }
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: text.isEmpty && attachedFood != null ? 'Расскажи мне об этом блюде' : text,
          isUser: true,
          timestamp: DateTime.now(),
          imagePath: imagePath,
          attachedFood: attachedFood,
        ),
      );
      _isLoading = true;
      _selectedImagePath = null;
      _attachedFood = null;
    });

    _messageController.clear();
    _scrollToBottom();

    // Формируем историю для отправки
    final chatHistory = _messages.skip(1).map((msg) => {
      'text': msg.text,
      'isUser': msg.isUser,
    }).toList();

    // Отправляем запрос (с фото или без)
    final Map<String, dynamic> result;
    if (imagePath != null) {
      result = await ApiHelper.sendChatMessageWithImage(
        File(imagePath),
        messageText,
        chatHistory: chatHistory,
      );
    } else {
      result = await ApiHelper.sendChatMessage(messageText, chatHistory: chatHistory);
    }

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _messages.add(
          ChatMessage(
            text: result['response'],
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: 'Извините, произошла ошибка. Попробуйте еще раз.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });

    // Обновляем профиль и лимиты после отправки сообщения
    if (result['success']) {
      // Обновляем профиль для актуального streak
      context.read<UserProvider>().loadProfile();
      
      // Обновляем лимиты
      final authProvider = context.read<AuthProvider>();
      final token = await authProvider.getToken();
      if (token != null) {
        context.read<LimitsProvider>().loadLimits(
          token,
          ApiHelper.baseUrl,
        );
      }
    }

    _scrollToBottom();
    _saveChatHistory();
  }

  Future<void> _sendImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      _selectedImagePath = image.path;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final limits = context.watch<LimitsProvider>().limits;
    
    return Scaffold(
      resizeToAvoidBottomInset: false, // Не поднимаем контент при открытии клавиатуры
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-Нутрициолог',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Всегда онлайн',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (limits != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: limits.messages.remaining > 0 
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: limits.messages.remaining > 0 
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: limits.messages.remaining > 0 
                            ? Colors.orange 
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${limits.messages.remaining}/${limits.messages.max}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: limits.messages.remaining > 0 
                              ? Colors.orange 
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить историю',
            onPressed: _clearChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            maxHeight: constraints.maxHeight,
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(), // Запрещаем скролл
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'AI-Нутрициолог',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'Задайте любой вопрос о питании, калориях или здоровом образе жизни',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildSuggestionChip('Что полезного съесть?'),
                        _buildSuggestionChip('Рецепт здорового завтрака'),
                        _buildSuggestionChip('Сколько калорий в яблоке?'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(String text) {
    final limits = context.watch<LimitsProvider>().limits;
    final isLimitReached = limits != null && limits.messages.remaining <= 0;
    
    return GestureDetector(
      onTap: isLimitReached ? null : () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppTheme.primaryOrange
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20).copyWith(
                  topLeft: message.isUser ? const Radius.circular(20) : Radius.zero,
                  topRight: message.isUser ? Radius.zero : const Radius.circular(20),
                ),
                border: message.isUser ? null : Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Карточка блюда если есть (как на фото)
                  if (message.attachedFood != null) ...[
                    _buildFoodCard(message.attachedFood!),
                    const SizedBox(height: 8),
                  ],
                  // Фото если есть
                  if (message.imagePath != null) ...[
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 250,
                        maxHeight: 250,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.file(
                            File(message.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Текст
                  if (message.text.isNotEmpty)
                    message.isUser
                        ? Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          )
                        : MarkdownBody(
                            data: message.text,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 15,
                              ),
                              strong: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              listBullet: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 15,
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(FoodModel food) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3C3C3C)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          // Изображение или эмодзи
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: food.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ImageHelper.buildImage(
                      food.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Center(
                        child: Text(
                          _getFoodEmoji(food.name),
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _getFoodEmoji(food.name),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
          ),
          
          const SizedBox(width: 12),
          
          // Информация о блюде
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${food.calories} ккал',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getFoodEmoji(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('мандарин') || name.contains('апельсин')) return '🍊';
    if (name.contains('яблок')) return '🍎';
    if (name.contains('банан')) return '🍌';
    if (name.contains('виноград')) return '🍇';
    if (name.contains('арбуз')) return '🍉';
    if (name.contains('клубник')) return '🍓';
    if (name.contains('хлеб') || name.contains('булк')) return '🍞';
    if (name.contains('яйц')) return '🥚';
    if (name.contains('молок') || name.contains('йогурт')) return '🥛';
    if (name.contains('курица') || name.contains('цыпл')) return '🍗';
    if (name.contains('мясо') || name.contains('стейк')) return '🥩';
    if (name.contains('рыб')) return '🐟';
    if (name.contains('салат')) return '🥗';
    if (name.contains('пицц')) return '🍕';
    if (name.contains('бургер')) return '🍔';
    if (name.contains('паста') || name.contains('спагетти')) return '🍝';
    if (name.contains('рис')) return '🍚';
    if (name.contains('суп')) return '🍲';
    if (name.contains('кофе')) return '☕';
    if (name.contains('торт') || name.contains('пирож')) return '🍰';
    if (name.contains('морожен')) return '🍦';
    if (name.contains('шоколад')) return '🍫';
    if (name.contains('печень')) return '🍪';
    return '🍽️';
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20).copyWith(
                topLeft: Radius.zero,
              ),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = (_animationController.value + (index * 0.33)) % 1.0;
        final opacity = (value < 0.5) ? value * 2 : (1 - value) * 2;
        
        return Opacity(
          opacity: opacity.clamp(0.3, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final limits = context.watch<LimitsProvider>().limits;
    final isLimitReached = limits != null && limits.messages.remaining <= 0;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Поднимаем над клавиатурой
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
          ),
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Предупреждение о лимите
          if (isLimitReached)
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
                      'Лимит сообщений исчерпан. Обновите до PRO для продолжения.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Превью прикрепленного блюда если есть (как на фото)
          if (_attachedFood != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3C3C3C)
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  // Изображение или эмодзи
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _attachedFood!.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ImageHelper.buildImage(
                              _attachedFood!.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: Center(
                                child: Text(
                                  _getFoodEmoji(_attachedFood!.name),
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _getFoodEmoji(_attachedFood!.name),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Информация о блюде
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachedFood!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_attachedFood!.calories} ккал',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Кнопка удалить
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _attachedFood = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Превью фото если выбрано
          if (_selectedImagePath != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImagePath!),
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImagePath = null;
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Кнопка скрепки
              IconButton(
                icon: Icon(
                  Icons.attach_file, 
                  color: isLimitReached 
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[400])
                      : Colors.grey[600],
                ),
                onPressed: isLimitReached ? null : _sendImage,
              ),
              // Поле ввода
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !isLimitReached,
                  decoration: InputDecoration(
                    hintText: isLimitReached
                        ? 'Лимит исчерпан...'
                        : _attachedFood != null
                            ? 'Введите свой вопрос здесь'
                            : _selectedImagePath != null 
                                ? 'Напишите запрос к фото...'
                                : 'Спросите что-нибудь...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isLimitReached 
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200])
                        : Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: isLimitReached ? null : (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка отправки
              Container(
                decoration: BoxDecoration(
                  gradient: isLimitReached ? null : AppTheme.primaryGradient,
                  color: isLimitReached
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1))
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_upward_rounded, 
                    color: isLimitReached 
                        ? const Color(0xFF94A3B8)
                        : Colors.white,
                    size: 22,
                  ),
                  onPressed: isLimitReached ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;
  final FoodModel? attachedFood;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
    this.attachedFood,
  });
}
