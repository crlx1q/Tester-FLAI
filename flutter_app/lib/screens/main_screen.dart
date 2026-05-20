import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/user_provider.dart';
import '../providers/limits_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/update_provider.dart';
import '../utils/api_helper.dart';
import 'home/home_screen.dart';
import 'chat/chat_screen.dart';
import 'recipes/recipes_screen.dart';
import 'profile/new_profile_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'friends/friends_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _needsOnboarding = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final result = await ApiHelper.getUnreadNotificationCount();
    if (mounted && result['success']) {
      setState(() {
        _unreadNotifications = result['count'] ?? 0;
      });
    }
  }

  Future<void> _checkOnboarding() async {
    final userProvider = context.read<UserProvider>();
    final limitsProvider = context.read<LimitsProvider>();
    final authProvider = context.read<AuthProvider>();
    
    await userProvider.loadProfile();
    // Убрали recordDailyVisit - streak теперь обновляется автоматически при активности
    
    // Загружаем лимиты пользователя
    final token = await authProvider.getToken();
    if (token != null) {
      await limitsProvider.loadLimits(
        token,
        ApiHelper.baseUrl,
      );
    }
    
    setState(() {
      _needsOnboarding = userProvider.user?.onboardingCompleted != true;
      _isLoading = false;
    });
    
    // Проверяем обновления (раз в 24 часа) и чистим старые APK
    _checkUpdatesAndCleanup();
  }

  Future<void> _checkUpdatesAndCleanup() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final updateProvider = context.read<UpdateProvider>();
      await updateProvider.checkForUpdatesIfNeeded(packageInfo.version);
      
      // Чистим старые APK файлы
      UpdateProvider.cleanupOldApks();
    } catch (e) {
      print('Update check error: $e');
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const RecipesScreen(),
    const FriendsScreen(),
    const NewProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_needsOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          setState(() {
            _needsOnboarding = false;
          });
        },
      );
    }

    return Consumer<UpdateProvider>(
      builder: (context, updateProvider, _) {
        return Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
              NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  
                  // Отмечаем обновление как просмотренное при переходе на профиль
                  if (index == 4 && updateProvider.hasUnreadUpdate) {
                    updateProvider.markUpdateAsSeen();
                  }
                  // Обновляем счётчик непрочитанных при возврате
                  if (index == 0) {
                    _loadUnreadCount();
                  }
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Главная',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'AI Чат',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.restaurant_menu_outlined),
                    selectedIcon: Icon(Icons.restaurant_menu),
                    label: 'Рецепты',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: _unreadNotifications > 0,
                      label: _unreadNotifications > 0 ? Text('$_unreadNotifications', style: const TextStyle(fontSize: 10, color: Colors.white)) : null,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.people_outline),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: _unreadNotifications > 0,
                      label: _unreadNotifications > 0 ? Text('$_unreadNotifications', style: const TextStyle(fontSize: 10, color: Colors.white)) : null,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.people),
                    ),
                    label: 'Друзья',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: updateProvider.hasUnreadUpdate,
                      backgroundColor: const Color(0xFFFF5A82),
                      child: const Icon(Icons.person_outline_rounded),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: updateProvider.hasUnreadUpdate,
                      backgroundColor: const Color(0xFFFF5A82),
                      child: const Icon(Icons.person_rounded),
                    ),
                    label: 'Профиль',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
