import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/api_helper.dart';
import '../../utils/theme.dart';
import 'change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  bool _isLoading = false;
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameController = TextEditingController(text: user?.name);
    _ageController = TextEditingController(text: user?.age?.toString());
    _heightController = TextEditingController(text: user?.height?.toString());
    _weightController = TextEditingController(text: user?.weight?.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (image != null) {
      setState(() {
        _avatarImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();
    
    // Сначала загружаем аватарку, если выбрана
    if (_avatarImage != null) {
      try {
        final token = await authProvider.getToken();
        if (token != null) {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiHelper.baseUrl}/profile/avatar'),
          );
          request.headers['Authorization'] = 'Bearer $token';
          request.files.add(
            await http.MultipartFile.fromPath('avatar', _avatarImage!.path),
          );
          
          final response = await request.send();
          if (response.statusCode != 200) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ошибка загрузки аватарки'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        print('Avatar upload error: $e');
      }
    }
    
    final profileData = {
      'name': _nameController.text,
      'age': int.tryParse(_ageController.text),
      'height': int.tryParse(_heightController.text),
      'weight': double.tryParse(_weightController.text),
    };

    final success = await userProvider.updateProfile(profileData);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль успешно обновлен'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка обновления профиля'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarImage == null
                            ? const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                              )
                            : null,
                        image: _avatarImage != null
                            ? DecorationImage(
                                image: FileImage(_avatarImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 3,
                        ),
                      ),
                      child: _avatarImage == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1F2937) : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Нажмите, чтобы изменить фото',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Возраст',
                prefixIcon: Icon(Icons.cake),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Рост (см)',
                prefixIcon: Icon(Icons.height),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Вес (кг)',
                prefixIcon: Icon(Icons.monitor_weight),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _navigateToChangePassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryOrange,
                  side: BorderSide(color: AppTheme.primaryOrange),
                ),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Сменить пароль'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _deleteProfile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Удалить профиль'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: const Text(
          'Вы уверены, что хотите удалить свой профиль? Это действие необратимо. Все ваши данные будут удалены.',
        ),
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

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = await authProvider.getToken();
      
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await http.delete(
        Uri.parse('${ApiHelper.baseUrl}/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Сохраняем контекст перед logout
        if (mounted) {
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          
          // Выходим из аккаунта
          await authProvider.logout();
          
          // Перенаправляем на логин
          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
          
          // Показываем уведомление
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Профиль успешно удален'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка удаления профиля'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка удаления профиля'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
