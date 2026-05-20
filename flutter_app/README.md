# FoodLens AI - Flutter Application

Мобильное приложение FoodLens AI на Flutter.

## 🚀 Запуск приложения

```bash
# Установка зависимостей
flutter pub get

# Запуск на эмуляторе/устройстве
flutter run

# Сборка APK для Android
flutter build apk

# Сборка для iOS
flutter build ios
```

## ⚙️ Настройка

### Подключение к серверу

В файле `lib/utils/api_helper.dart` измените `baseUrl`:

```dart
// Для реального устройства используйте IP вашего компьютера
static const String baseUrl = 'http://192.168.1.XXX:3000/api';

// Для Android эмулятора
static const String baseUrl = 'http://10.0.2.2:3000/api';

// Для iOS симулятора
static const String baseUrl = 'http://localhost:3000/api';
```

## 📱 Особенности

- **State Management**: Provider
- **Navigation**: Flutter Navigator 2.0
- **Themes**: Material Design 3 (светлая и темная)
- **Fonts**: Google Fonts (Manrope)
- **Charts**: FL Chart
- **Image Picker**: Camera и галерея

## 🎨 Структура проекта

```
lib/
├── main.dart              # Точка входа
├── models/                # Модели данных
│   ├── user_model.dart
│   └── food_model.dart
├── providers/             # State management
│   ├── auth_provider.dart
│   ├── theme_provider.dart
│   └── user_provider.dart
├── screens/               # UI экраны
│   ├── auth/
│   ├── home/
│   ├── chat/
│   ├── recipes/
│   ├── profile/
│   └── onboarding/
└── utils/                 # Утилиты
    ├── api_helper.dart
    └── theme.dart
```

## 🔑 Основные экраны

1. **Auth** - Вход и регистрация
2. **Onboarding** - Настройка профиля (5 шагов)
3. **Home** - Дневник питания и калории
4. **Chat** - AI-нутрициолог
5. **Recipes** - Рецепты с фильтрами
6. **Profile** - Профиль и настройки

## 📦 Зависимости

Основные пакеты в `pubspec.yaml`:

- `provider` - Управление состоянием
- `http` / `dio` - Сетевые запросы
- `google_fonts` - Шрифты
- `image_picker` - Работа с камерой
- `fl_chart` - Графики
- `shared_preferences` - Локальное хранилище

## 🐛 Отладка

```bash
# Проверка подключения к серверу
curl http://localhost:3000/api/health

# Логи Flutter
flutter logs
```
