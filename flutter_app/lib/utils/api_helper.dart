import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

class ApiHelper {
  // IP адрес вашего компьютера в локальной сети
  static const String baseUrl = 'https://foodlensai.reflexai.pro/api';
  static const String mediaUrl = 'https://foodlensai.reflexai.pro';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getHeaders(
      {bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? username,
  }) async {
    try {
      final body = {
        'email': email,
        'password': password,
        'name': name,
      };
      if (username != null && username.isNotEmpty) {
        body['username'] = username;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final result = _handleResponse(response);

      if (result['success'] && result['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', result['token']);
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Profile endpoints
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> completeOnboarding(
      Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/onboarding'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> cancelSubscription() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/cancel-subscription'),
        headers: await _getHeaders(),
        body: jsonEncode({}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Food endpoints
  static Future<Map<String, dynamic>> analyzeFood(File imageFile) async {
    try {
      // Читаем файл
      final bytes = await imageFile.readAsBytes();

      // ✅ СЖИМАЕМ ИЗОБРАЖЕНИЕ НА СТОРОНЕ КЛИЕНТА!
      final image = img.decodeImage(bytes);

      if (image == null) {
        return {
          'success': false,
          'message': 'Не удалось прочитать изображение'
        };
      }

      // Определяем целевой размер (максимум 1024px по большей стороне)
      int targetWidth = image.width;
      int targetHeight = image.height;
      const maxSize = 1024;

      if (image.width > maxSize || image.height > maxSize) {
        if (image.width > image.height) {
          targetWidth = maxSize;
          targetHeight = (image.height * maxSize / image.width).round();
        } else {
          targetHeight = maxSize;
          targetWidth = (image.width * maxSize / image.height).round();
        }
      }

      // Изменяем размер и сжимаем с качеством 75%
      final resized = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

      final compressed = img.encodeJpg(resized, quality: 75);

      // Конвертируем в base64
      final base64Image = 'data:image/jpeg;base64,${base64Encode(compressed)}';

      // Используем новый endpoint с Gemini Vision
      return await analyzeFoodImage(base64Image);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки изображения'};
    }
  }

  static Future<Map<String, dynamic>> getFoodHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food/history'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> getDailySummary({DateTime? date}) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) {
        queryParams['date'] =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      final uri = Uri.parse('$baseUrl/food/daily-summary')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Получить статистику за неделю для графика
  static Future<Map<String, dynamic>> getWeeklyProgress() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food/weekly-progress'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Получить активные дни месяца
  static Future<Map<String, dynamic>> getMonthlyActiveDays(
      {required int year, required int month}) async {
    try {
      final queryParams = {
        'year': year.toString(),
        'month': month.toString(),
      };

      final uri = Uri.parse('$baseUrl/food/monthly-active-days')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Обновить блюдо
  static Future<Map<String, dynamic>> updateFood(
      String foodId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/food/$foodId'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Обновить блюдо с фото и новым названием через AI
  static Future<Map<String, dynamic>> updateFoodWithImage(
      String foodId, String newName, String imageBase64) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/food/$foodId/update-with-image'),
        headers: await _getHeaders(),
        body: json.encode({
          'newName': newName,
          'image': imageBase64,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Удалить блюдо
  static Future<Map<String, dynamic>> deleteFood(String foodId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/food/$foodId'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Добавить блюдо в избранное
  static Future<Map<String, dynamic>> addToFavorites(String foodId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/food/$foodId/favorite'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Получить избранные блюда
  static Future<Map<String, dynamic>> getFavoriteFoods() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food/favorites/list'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Удалить из избранного
  static Future<Map<String, dynamic>> removeFavoriteFood(
      String favoriteId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/food/favorites/$favoriteId'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Добавить избранное блюдо в дневник
  static Future<Map<String, dynamic>> addFavoriteToDiary(
      String favoriteId) async {
    try {
      final localHour = DateTime.now().hour;
      final response = await http.post(
        Uri.parse('$baseUrl/food/favorites/$favoriteId/add-to-diary'),
        headers: await _getHeaders(),
        body: json.encode({'localHour': localHour}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Анализ описания блюда через AI (создаёт новое блюдо)
  static Future<Map<String, dynamic>> analyzeFoodDescription(
      String description) async {
    try {
      final localHour = DateTime.now().hour;
      final response = await http.post(
        Uri.parse('$baseUrl/food/analyze-description'),
        headers: await _getHeaders(),
        body: json.encode({
          'description': description,
          'localHour': localHour,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Только анализ описания (НЕ создаёт блюдо)
  static Future<Map<String, dynamic>> analyzeFoodDescriptionOnly(
      String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/food/analyze-only'),
        headers: await _getHeaders(),
        body: json.encode({'description': description}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Анализ изображения блюда через Gemini Vision
  static Future<Map<String, dynamic>> analyzeFoodImage(
      String imageBase64) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        final localHour = DateTime.now().hour;
        final response = await http
            .post(
          Uri.parse('$baseUrl/food/analyze-image'),
          headers: await _getHeaders(),
          body: json.encode({
            'image': imageBase64,
            'localHour': localHour,
          }),
        )
            .timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            throw TimeoutException('Превышено время ожидания');
          },
        );

        return _handleResponse(response);
      } on TimeoutException {
        if (attempts >= maxAttempts) {
          return {
            'success': false,
            'message':
                'Превышено время ожидания. Попробуйте еще раз или проверьте интернет-соединение.'
          };
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      } on SocketException {
        if (attempts >= maxAttempts) {
          return {
            'success': false,
            'message': 'Нет подключения к интернету. Проверьте соединение.'
          };
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      } catch (e) {
        if (attempts >= maxAttempts) {
          return {'success': false, 'message': 'Ошибка подключения к серверу'};
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }

    return {
      'success': false,
      'message': 'Не удалось отправить после $maxAttempts попыток'
    };
  }

  // AI Chat endpoints
  static Future<Map<String, dynamic>> sendChatMessage(
    String message, {
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    try {
      final body = {
        'message': message,
        if (chatHistory != null) 'chatHistory': chatHistory,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> sendChatMessageWithImage(
    File imageFile,
    String message, {
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/chat-image'),
      );

      final token = await _getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Content-Type'] = 'multipart/form-data';

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      request.fields['message'] = message;
      if (chatHistory != null) {
        request.fields['chatHistory'] = jsonEncode(chatHistory);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки изображения'};
    }
  }

  // Recipes endpoints
  static Future<Map<String, dynamic>> getRecipes({
    String? category,
    List<String>? allergies,
    String? goal,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (goal != null) queryParams['goal'] = goal;
      if (allergies != null && allergies.isNotEmpty) {
        queryParams['allergies'] = allergies.join(',');
      }

      final uri =
          Uri.parse('$baseUrl/recipes').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  static Future<Map<String, dynamic>> generateRecipe({
    required String dishName,
    String? imagePath,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/recipes/generate'),
      );

      request.headers.addAll(await _getHeaders());
      request.fields['dishName'] = dishName;

      if (imagePath != null && imagePath.isNotEmpty) {
        request.files
            .add(await http.MultipartFile.fromPath('image', imagePath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации рецепта: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRecipeDetails(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки рецепта'};
    }
  }

  static Future<Map<String, dynamic>> deleteRecipe(String recipeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/recipes/$recipeId'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления рецепта'};
    }
  }

  static Future<Map<String, dynamic>> toggleRecipeFavorite(
      String recipeId, bool isFavorite) async {
    try {
      final response = isFavorite
          ? await http.delete(
              Uri.parse('$baseUrl/recipes/$recipeId/favorite'),
              headers: await _getHeaders(),
            )
          : await http.post(
              Uri.parse('$baseUrl/recipes/$recipeId/favorite'),
              headers: await _getHeaders(),
            );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления избранного'};
    }
  }

  static Future<Map<String, dynamic>> getFavoriteRecipes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/favorites/my'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка загрузки избранных рецептов'
      };
    }
  }

  // Streak endpoint
  static Future<Map<String, dynamic>> recordDailyVisit() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Onboarding with AI personalization
  static Future<Map<String, dynamic>> completeOnboardingWithAI(
      Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/onboarding/complete'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу'};
    }
  }

  // Water tracking endpoints
  static Future<Map<String, dynamic>> getWaterIntake(String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food/water/$date'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения данных о воде'};
    }
  }

  static Future<Map<String, dynamic>> saveWaterIntake(
      String date, int amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/food/water'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'date': date,
          'amount': amount,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения данных о воде'};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, ...data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Произошла ошибка',
      };
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // AI meal advice
  static Future<Map<String, dynamic>> getAiMealAdvice() async {
    try {
      final hour = DateTime.now().hour;
      final uri = Uri.parse('$baseUrl/ai/meal-advice')
          .replace(queryParameters: {'hour': hour.toString()});
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения совета AI'};
    }
  }

  // AI daily summary (Pro only)
  static Future<Map<String, dynamic>> getAiDailySummary() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/daily-summary'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения дневной сводки'};
    }
  }

  // Version check endpoint
  static Future<Map<String, dynamic>> checkVersion(
      String currentVersion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check-version'),
        headers: await _getHeaders(includeAuth: false),
        body: jsonEncode({
          'currentVersion': currentVersion,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка проверки версии'};
    }
  }

  // ==================== FRIENDS ====================

  static Future<Map<String, dynamic>> searchFriends(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/friends/search')
          .replace(queryParameters: {'q': query});
      final response = await http.get(uri, headers: await _getHeaders());
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка поиска'};
    }
  }

  static Future<Map<String, dynamic>> sendFriendRequest(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request/$userId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка отправки запроса'};
    }
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(String friendshipId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept/$friendshipId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка принятия запроса'};
    }
  }

  static Future<Map<String, dynamic>> rejectFriendRequest(String friendshipId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/reject/$friendshipId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка отклонения запроса'};
    }
  }

  static Future<Map<String, dynamic>> removeFriend(String friendshipId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/friends/$friendshipId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления'};
    }
  }

  static Future<Map<String, dynamic>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки друзей'};
    }
  }

  static Future<Map<String, dynamic>> getFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки запросов'};
    }
  }

  static Future<Map<String, dynamic>> getFriendProgress(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/$userId/progress'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки прогресса'};
    }
  }

  // ==================== NOTIFICATIONS ====================

  static Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    try {
      final uri = Uri.parse('$baseUrl/notifications')
          .replace(queryParameters: {'page': page.toString()});
      final response = await http.get(uri, headers: await _getHeaders());
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка загрузки уведомлений'};
    }
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-read/$id'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-all-read'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$id'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления'};
    }
  }

  static Future<Map<String, dynamic>> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/settings'),
        headers: await _getHeaders(),
        body: jsonEncode(settings),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения настроек'};
    }
  }

  static Future<Map<String, dynamic>> updateFcmToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({'token': token}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка'};
    }
  }

  // ==================== USERNAME ====================

  static Future<Map<String, dynamic>> updateUsername(String username) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления username'};
    }
  }
}
