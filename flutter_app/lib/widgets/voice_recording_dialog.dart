import 'package:flutter/material.dart';
import '../services/speech_service.dart';

class VoiceRecordingDialog extends StatefulWidget {
  final Function(String) onTextRecognized;
  
  const VoiceRecordingDialog({
    super.key,
    required this.onTextRecognized,
  });

  @override
  State<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<VoiceRecordingDialog> 
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _statusText = 'Нажмите микрофон для записи';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _checkSpeechAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkSpeechAvailability() async {
    final available = await SpeechService.isAvailable();
    setState(() {
      _speechAvailable = available;
      if (!available) {
        _statusText = 'Распознавание речи недоступно. Введите текстом.';
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(() {
        _statusText = 'Распознавание речи недоступно';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _statusText = 'Слушаю... Говорите';
    });

    final result = await SpeechService.startListening();
    
    setState(() {
      _isListening = false;
    });
    
    if (result != null && result.isNotEmpty) {
      // Сразу отправляем результат
      widget.onTextRecognized(result);
      Navigator.pop(context);
    } else {
      setState(() {
        _statusText = 'Ничего не услышал. Попробуйте еще раз';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mic, color: Colors.green, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Запись голосом',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Анимация микрофона
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Анимированные круги
                  if (_isListening) ...[
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 100 * _scaleAnimation.value,
                          height: 100 * _scaleAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(0.1),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 80 * _scaleAnimation.value,
                          height: 80 * _scaleAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(0.2),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Кнопка микрофона
                  GestureDetector(
                    onTap: _isListening ? null : _startListening,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : Colors.green)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Статус
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 14,
                  color: _isListening ? Colors.green : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
