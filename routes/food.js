const express = require('express');
const multer = require('multer');
const path = require('path');
const authMiddleware = require('../middleware/auth');
const { checkPhotoLimit } = require('../middleware/usage-limits');
const { checkFileSizeLimit, compressImage, compressBase64Image, checkBase64SizeLimit } = require('../middleware/image-compression');
const Database = require('../utils/database');
const { analyzeFood, generateMealAdvice } = require('../services/ai-service');
const { getCurrentDate, getTodayStart, getLocalDay, getDaysDifference, TIMEZONE } = require('../utils/timezone');

const router = express.Router();

// Утилита для определения типа приема пищи по времени
function getMealTypeByHour(hour) {
  if (hour >= 6 && hour < 12) return 'Завтрак';
  if (hour >= 12 && hour < 16) return 'Обед';
  if (hour >= 16 && hour < 21) return 'Ужин';
  return 'Перекус';
}

// Получить локальный час из запроса или использовать серверное время
function getLocalHour(req) {
  // Проверяем query параметры (для multipart форм)
  if (req.query && req.query.localHour !== undefined) {
    return parseInt(req.query.localHour);
  }
  // Проверяем body (для JSON запросов)
  if (req.body && req.body.localHour !== undefined) {
    return parseInt(req.body.localHour);
  }
  // Иначе используем серверное время (уже в Asia/Almaty!)
  return new Date().getHours();
}

// Настройка загрузки файлов
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'food-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB временный лимит (будет проверяться в middleware)
  fileFilter: (req, file, cb) => {
    // Разрешенные mime types
    const allowedMimeTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/heic',
      'image/heif'
    ];
    
    // Проверяем mime type
    if (allowedMimeTypes.includes(file.mimetype.toLowerCase())) {
      return cb(null, true);
    }
    
    // Дополнительная проверка расширения файла
    const allowedExtensions = /\.(jpg|jpeg|png|gif|webp|heic|heif)$/i;
    if (allowedExtensions.test(file.originalname)) {
      return cb(null, true);
    }
    
    cb(new Error('Только изображения разрешены (JPG, PNG, GIF, WEBP, HEIC)'));
  }
});

// Анализ еды по фото
router.post('/analyze', authMiddleware, upload.single('image'), checkFileSizeLimit, compressImage, async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Изображение не загружено'
      });
    }
    
    // Получаем пользователя для персонализации
    const user = await Database.getUserById(req.userId);
    
    // Анализируем изображение через AI
    const analysis = await analyzeFood(req.file.path, user);
    
    // Определяем тип приема пищи по времени (используем локальное время клиента)
    const hour = getLocalHour(req);
    const mealType = getMealTypeByHour(hour);
    
    // Читаем файл и конвертируем в Buffer для MongoDB
    const fs = require('fs');
    const imageBuffer = fs.readFileSync(req.file.path);
    
    // Удаляем временный файл
    fs.unlinkSync(req.file.path);
    
    // Сохраняем в базу с Buffer (НЕ путь к файлу!)
    const foodData = {
      userId: req.userId,
      name: (analysis.name && analysis.name.trim() !== '') ? analysis.name : 'Блюдо',
      imageUrl: `data:image/jpeg;base64,${imageBuffer.toString('base64')}`, // ✅ Base64 для createFood
      calories: analysis.calories || 0,
      macros: analysis.macros || { protein: 0, fat: 0, carbs: 0 },
      mealType
    };
    
    console.log('💾 Saving food to database:', {
      ...foodData,
      imageUrl: foodData.imageUrl.substring(0, 50) + '...' // Не логируем весь base64
    });
    
    const newFood = await Database.createFood(foodData);
    
    // Преобразуем в объект с виртуальными полями
    const foodObject = newFood.toObject();
    
    res.json({
      success: true,
      food: foodObject
    });
  } catch (error) {
    console.error('Food analysis error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Ошибка анализа изображения'
    });
  }
});

// История еды
router.get('/history', authMiddleware, async (req, res) => {
  try {
    const foods = await Database.getFoods(req.userId);
    
    // Сортируем по дате (новые первые)
    foods.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Преобразуем Mongoose документы в объекты с виртуальными полями
    const foodsWithImages = foods.map(food => food.toObject ? food.toObject() : food);
    
    console.log(`📋 История еды для пользователя ${req.userId}: ${foodsWithImages.length} блюд`);
    if (foodsWithImages.length > 0) {
      console.log(`🖼️ Первое блюдо имеет imageUrl: ${!!foodsWithImages[0].imageUrl}`);
    }
    
    res.json({
      success: true,
      foods: foodsWithImages
    });
  } catch (error) {
    console.error('Get food history error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения истории'
    });
  }
});

// Дневная сводка
router.get('/daily-summary', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Получаем дату из query параметра или используем сегодня
    let targetDate = new Date();
    if (req.query.date) {
      targetDate = new Date(req.query.date);
    }
    
    const dayFoods = await Database.getFoodsByDate(req.userId, targetDate);
    
    // Подсчитываем калории и макросы
    let totalCalories = 0;
    let consumedMacros = { carbs: 0, protein: 0, fat: 0 };
    
    dayFoods.forEach(food => {
      totalCalories += food.calories || 0;
      if (food.macros) {
        consumedMacros.carbs += food.macros.carbs || 0;
        consumedMacros.protein += food.macros.protein || 0;
        consumedMacros.fat += food.macros.fat || 0;
      }
    });
    
    const remainingCalories = (user.dailyCalories || 2000) - totalCalories;
    
    // Преобразуем Mongoose документы в объекты с виртуальными полями
    const foodsWithImages = dayFoods.map(food => food.toObject ? food.toObject() : food);
    
    res.json({
      success: true,
      data: {
        totalCalories,
        targetCalories: user.dailyCalories || 2000,
        remainingCalories,
        consumedMacros,
        targetMacros: user.macros || { carbs: 270, protein: 130, fat: 58 },
        foods: foodsWithImages
      }
    });
  } catch (error) {
    console.error('Get daily summary error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения сводки'
    });
  }
});

// Прогресс за неделю
router.get('/weekly-progress', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    const weekData = [];
    
    // Получаем данные за последние 7 дней
    for (let i = 6; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      date.setHours(0, 0, 0, 0);
      
      const dayFoods = await Database.getFoodsByDate(req.userId, date);
      const totalCalories = dayFoods.reduce((sum, f) => sum + f.calories, 0);
      const percentage = user.dailyCalories > 0 
        ? Math.round((totalCalories / user.dailyCalories) * 100) 
        : 0;
      
      weekData.push({
        date: date.toISOString().split('T')[0],
        totalCalories,
        targetCalories: user.dailyCalories,
        percentage,
        foodCount: dayFoods.length
      });
    }
    
    res.json({
      success: true,
      data: weekData
    });
  } catch (error) {
    console.error('Get weekly progress error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения прогресса'
    });
  }
});

// Активные дни месяца
router.get('/monthly-active-days', authMiddleware, async (req, res) => {
  try {
    const { year, month } = req.query;
    
    if (!year || !month) {
      return res.status(400).json({
        success: false,
        message: 'Год и месяц обязательны'
      });
    }
    
    // Получаем пользователя для проверки lastVisit
    const user = await Database.getUserById(req.userId);
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? getLocalDay(lastVisit) : null;
    
    // Используем UTC даты для корректной работы с часовыми поясами
    const startDate = new Date(Date.UTC(parseInt(year), parseInt(month) - 1, 1));
    const endDate = new Date(Date.UTC(parseInt(year), parseInt(month), 0, 23, 59, 59, 999));
    
    const activeDays = [];
    const currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      let isActive = false;
      
      // Проверяем наличие записей еды
      const foods = await Database.getFoodsByDate(req.userId, currentDate);
      if (foods && foods.length > 0) {
        isActive = true;
      }
      
      // Проверяем, совпадает ли lastVisit с этим днём
      if (!isActive && lastVisitDay) {
        const checkDay = getLocalDay(currentDate);
        if (checkDay.getTime() === lastVisitDay.getTime()) {
          isActive = true;
        }
      }
      
      if (isActive) {
        // Используем UTC дату для строки
        const dateStr = currentDate.toISOString().split('T')[0];
        activeDays.push(dateStr);
      }
      
      // Переходим к следующему дню в UTC
      currentDate.setUTCDate(currentDate.getUTCDate() + 1);
    }
    
    res.json({
      success: true,
      data: activeDays
    });
  } catch (error) {
    console.error('Monthly active days error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения активных дней'
    });
  }
});

// Обновить блюдо
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const food = await Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId.toString() !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет доступа к этому блюду'
      });
    }
    
    const { name, calories, macros, healthScore } = req.body;
    
    console.log('🔄 Обновление блюда:', {
      id: req.params.id,
      старое: { name: food.name, calories: food.calories },
      новое: { name, calories, healthScore }
    });
    
    const updatedFood = await Database.updateFood(req.params.id, {
      name,
      calories,
      macros,
      healthScore
    });
    
    console.log('✅ Блюдо обновлено:', updatedFood._id);
    
    // Преобразуем в объект с виртуальными полями
    const foodObject = updatedFood.toObject ? updatedFood.toObject() : updatedFood;
    
    res.json({
      success: true,
      message: 'Блюдо успешно обновлено',
      food: foodObject
    });
  } catch (error) {
    console.error('Update food error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления блюда'
    });
  }
});

// Обновить блюдо с фото и новым названием через AI
router.put('/:id/update-with-image', authMiddleware, async (req, res) => {
  try {
    const food = await Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (!food.userId.equals(req.userId)) {
      return res.status(403).json({
        success: false,
        message: 'Нет доступа к этому блюду'
      });
    }
    
    const { newName, image } = req.body;
    
    if (!newName || !image) {
      return res.status(400).json({
        success: false,
        message: 'Название и изображение обязательны'
      });
    }
    
    console.log('🔄 Обновление блюда с фото через AI:', {
      id: req.params.id,
      oldName: food.name,
      newName: newName
    });
    
    // Извлекаем base64 данные
    const base64Data = image.includes('base64,') 
      ? image.split('base64,')[1] 
      : image;
    
    const { analyzeImageFoodWithName } = require('../utils/ai');
    
    // Анализируем через Gemini Vision с учетом нового названия
    const foodData = await analyzeImageFoodWithName(base64Data, newName);
    
    console.log('📊 AI Analysis Result:', JSON.stringify(foodData, null, 2));
    
    // Формируем название с emoji (как при создании блюда)
    const emoji = foodData.emoji || '🍽️';
    const nameWithEmoji = `${emoji} ${foodData.name || newName}`;
    
    const updateData = {
      name: nameWithEmoji,
      calories: foodData.calories || 0,
      macros: foodData.macros || { protein: 0, fat: 0, carbs: 0 },
      healthScore: foodData.healthScore !== undefined ? foodData.healthScore : 50
    };
    
    console.log('💾 Данные для обновления в MongoDB:', JSON.stringify(updateData, null, 2));
    
    // Обновляем блюдо
    const updatedFood = await Database.updateFood(req.params.id, updateData);
    
    if (!updatedFood) {
      console.error('❌ Блюдо не найдено после обновления!');
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено после обновления'
      });
    }
    
    console.log('✅ Блюдо обновлено в MongoDB:', {
      id: updatedFood._id,
      name: updatedFood.name,
      calories: updatedFood.calories,
      macros: updatedFood.macros
    });
    
    // Преобразуем в объект с виртуальными полями
    const foodObject = updatedFood.toObject ? updatedFood.toObject() : updatedFood;
    
    res.json({
      success: true,
      message: 'Блюдо успешно обновлено с учетом фото',
      food: foodObject,
      analysis: foodData
    });
    
  } catch (error) {
    console.error('Update food with image error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления блюда: ' + error.message
    });
  }
});

// Удалить блюдо
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const food = await Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId.toString() !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет доступа к этому блюду'
      });
    }
    
    // Изображения хранятся в MongoDB как Buffer, удаление файлов не требуется
    
    await Database.deleteFood(req.params.id);
    
    res.json({
      success: true,
      message: 'Блюдо успешно удалено'
    });
  } catch (error) {
    console.error('Delete food error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления блюда'
    });
  }
});

// Добавить блюдо в избранное
router.post('/:id/favorite', authMiddleware, async (req, res) => {
  try {
    const food = await Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Любой пользователь может добавить любое блюдо в свое избранное
    // Убираем проверку владельца - это избранное, а не редактирование!
    
    const favoriteFood = await Database.addFavoriteFood(req.userId, {
      name: food.name,
      calories: food.calories,
      macros: food.macros
    });
    
    res.json({
      success: true,
      message: 'Блюдо добавлено в избранное',
      favoriteFood
    });
  } catch (error) {
    console.error('Add favorite food error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка добавления в избранное'
    });
  }
});

// Получить избранные блюда
router.get('/favorites/list', authMiddleware, async (req, res) => {
  try {
    const favoriteFoods = await Database.getFavoriteFoods(req.userId);
    
    // Преобразуем Mongoose документы в объекты с виртуальными полями
    const foodsWithImages = favoriteFoods.map(food => food.toObject ? food.toObject() : food);
    
    res.json({
      success: true,
      favoriteFoods: foodsWithImages
    });
  } catch (error) {
    console.error('Get favorite foods error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения избранных блюд'
    });
  }
});

// Удалить блюдо из избранного
router.delete('/favorites/:id', authMiddleware, async (req, res) => {
  try {
    await Database.removeFavoriteFood(req.userId, req.params.id);
    
    res.json({
      success: true,
      message: 'Блюдо удалено из избранного'
    });
  } catch (error) {
    console.error('Remove from favorites error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления из избранного'
    });
  }
});

// Добавить избранное блюдо в дневник
router.post('/favorites/:id/add-to-diary', authMiddleware, async (req, res) => {
  try {
    const favoriteFoods = await Database.getFavoriteFoods(req.userId);
    const favoriteFood = favoriteFoods.find(f => f._id.toString() === req.params.id);
    
    if (!favoriteFood) {
      console.log(`❌ Избранное блюдо не найдено. ID: ${req.params.id}, Всего избранных: ${favoriteFoods.length}`);
      return res.status(404).json({
        success: false,
        message: 'Избранное блюдо не найдено'
      });
    }
    
    // Определяем тип приема пищи по времени (используем локальное время клиента)
    const hour = getLocalHour(req);
    const mealType = getMealTypeByHour(hour);
    
    // Создаем новое блюдо в дневнике
    const foodData = {
      userId: req.userId,
      name: favoriteFood.name,
      imageUrl: null, // Избранное без фото
      calories: favoriteFood.calories,
      macros: favoriteFood.macros,
      mealType
    };
    
    const newFood = await Database.createFood(foodData);
    const foodObject = newFood.toObject ? newFood.toObject() : newFood;
    
    res.json({
      success: true,
      message: 'Блюдо добавлено в дневник',
      food: foodObject
    });
  } catch (error) {
    console.error('Add favorite to diary error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка добавления блюда в дневник'
    });
  }
});

// Только анализ описания (без создания блюда)
router.post('/analyze-only', authMiddleware, async (req, res) => {
  try {
    const { description } = req.body;
    
    if (!description || description.trim().length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Описание блюда обязательно' 
      });
    }

    const { analyzeTextDescription } = require('../utils/ai');
    
    // Только анализируем через Gemini AI (не создаем блюдо)
    const foodData = await analyzeTextDescription(description);
    
    res.json({ 
      success: true, 
      analysis: foodData
    });
    
  } catch (error) {
    console.error('Ошибка анализа описания:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Ошибка анализа описания: ' + error.message
    });
  }
});

// Анализ описания блюда через Gemini AI
router.post('/analyze-description', authMiddleware, async (req, res) => {
  try {
    const { description } = req.body;
    
    if (!description || description.trim().length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Описание блюда обязательно' 
      });
    }

    const { analyzeTextDescription } = require('../utils/ai');
    
    // Анализируем через Gemini AI
    const foodData = await analyzeTextDescription(description);
    
    // Определяем тип приема пищи по времени (используем локальное время клиента)
    const hour = getLocalHour(req);
    const mealType = getMealTypeByHour(hour);
    
    // Добавляем блюдо в дневник
    const emoji = foodData.emoji || '🍽️';
    const name = foodData.name || 'Неизвестное блюдо';
    const newFood = Database.createFood({
      userId: req.userId,
      name: `${emoji} ${name}`,
      calories: foodData.calories || 0,
      macros: foodData.macros || { protein: 0, fat: 0, carbs: 0 },
      healthScore: foodData.healthScore !== undefined ? foodData.healthScore : 50,
      imageUrl: null,
      mealType
    });
    
    // Обновляем streak (активность пользователя)
    const user = await Database.getUserById(req.userId);
    const now = new Date(); // UTC время для сохранения в базу
    const today = getTodayStart();
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? getLocalDay(lastVisit) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    let shouldUpdate = false;
    
    if (lastVisitDay) {
      const diffDays = getDaysDifference(today, lastVisitDay);
      if (diffDays === 0) {
        // Сегодня уже была активность - не обновляем
        shouldUpdate = false;
      } else if (diffDays === 1) {
        // Вчера была активность - продолжаем серию
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
        shouldUpdate = true;
      } else {
        // Пропустили 2+ дня - начинаем новую серию
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
        shouldUpdate = true;
      }
    } else {
      // Первый визит
      newStreak = 1;
      maxStreak = 1;
      shouldUpdate = true;
    }
    
    if (shouldUpdate) {
      await Database.updateUser(req.userId, {
        streak: newStreak,
        maxStreak: maxStreak,
        lastVisit: now.toISOString()
      });
    }
    
    res.json({ 
      success: true, 
      food: newFood,
      analysis: foodData
    });
    
  } catch (error) {
    console.error('Ошибка анализа описания:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Ошибка анализа описания: ' + error.message
    });
  }
});

// Анализ изображения блюда через Gemini Vision
router.post('/analyze-image', authMiddleware, checkPhotoLimit, async (req, res) => {
  try {
    const { image } = req.body;
    
    if (!image) {
      return res.status(400).json({ 
        success: false, 
        message: 'Изображение обязательно' 
      });
    }

    // Извлекаем base64 данные (убираем префикс data:image/jpeg;base64,)
    let base64Data = image.includes('base64,') 
      ? image.split('base64,')[1] 
      : image;
    
    // ✅ ПРОВЕРКА РАЗМЕРА: максимум 25 MB (защита от модов)
    const buffer = Buffer.from(base64Data, 'base64');
    const fileSizeMB = buffer.length / (1024 * 1024);
    const maxSizeMB = 25;
    
    if (fileSizeMB > maxSizeMB) {
      console.log(`❌ Файл слишком большой: ${fileSizeMB.toFixed(2)} MB (лимит ${maxSizeMB} MB)`);
      return res.status(413).json({
        success: false,
        message: `Превышен размер файла: ${fileSizeMB.toFixed(1)} MB. Максимум ${maxSizeMB} MB.`
      });
    }
    
    console.log(`📸 Изображение принято: ${fileSizeMB.toFixed(2)} MB`);
    
    // ✅ НЕ СЖИМАЕМ! Клиент уже сжал, сразу отправляем в AI

    const { analyzeImageFood } = require('../utils/ai');
    
    // Анализируем через Gemini Vision
    const foodData = await analyzeImageFood(base64Data);
    
    // Определяем тип приема пищи по времени (используем локальное время клиента)
    const hour = getLocalHour(req);
    const mealType = getMealTypeByHour(hour);
    
    // Добавляем блюдо в дневник
    const name = foodData.name || 'Неизвестное блюдо';
    const foodToSave = {
      userId: req.userId,
      name: name,
      calories: foodData.calories || 0,
      macros: foodData.macros || { protein: 0, fat: 0, carbs: 0 },
      healthScore: foodData.healthScore !== undefined ? foodData.healthScore : 50,
      imageUrl: `data:image/jpeg;base64,${base64Data}`,
      mealType
    };
    
    const newFood = await Database.createFood(foodToSave);
    
    // Преобразуем в объект с виртуальными полями
    const foodObject = newFood.toObject();
    
    // Увеличиваем счетчик использования
    await Database.incrementUserUsage(req.userId, 'photos');
    
    // Обновляем streak (активность пользователя)
    const user = await Database.getUserById(req.userId);
    const now = new Date(); // UTC время для сохранения в базу
    const today = getTodayStart();
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? getLocalDay(lastVisit) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    let shouldUpdate = false;
    
    if (lastVisitDay) {
      const diffDays = getDaysDifference(today, lastVisitDay);
      if (diffDays === 0) {
        // Сегодня уже была активность - не обновляем
        shouldUpdate = false;
      } else if (diffDays === 1) {
        // Вчера была активность - продолжаем серию
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
        shouldUpdate = true;
      } else {
        // Пропустили 2+ дня - начинаем новую серию
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
        shouldUpdate = true;
      }
    } else {
      // Первый визит
      newStreak = 1;
      maxStreak = 1;
      shouldUpdate = true;
    }
    
    if (shouldUpdate) {
      await Database.updateUser(req.userId, {
        streak: newStreak,
        maxStreak: maxStreak,
        lastVisit: now.toISOString()
      });
    }
    
    res.json({ 
      success: true, 
      food: foodObject, // ✅ Объект с виртуальными полями!
      analysis: foodData
    });
    
  } catch (error) {
    console.error('Ошибка анализа изображения:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Ошибка анализа изображения: ' + error.message
    });
  }
});

// ==================== WATER TRACKING ====================

// Получить данные о воде за конкретную дату
router.get('/water/:date', authMiddleware, async (req, res) => {
  try {
    const { date } = req.params;
    
    if (!date) {
      return res.status(400).json({
        success: false,
        message: 'Дата обязательна'
      });
    }
    
    const waterIntake = await Database.getWaterIntakeByDate(req.userId, date);
    
    res.json({
      success: true,
      waterIntake: waterIntake || { amount: 0 }
    });
  } catch (error) {
    console.error('Get water intake error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения данных о воде'
    });
  }
});

// Сохранить данные о воде
router.post('/water', authMiddleware, async (req, res) => {
  try {
    const { date, amount } = req.body;
    
    if (!date || amount === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Дата и количество обязательны'
      });
    }
    
    if (amount < 0) {
      return res.status(400).json({
        success: false,
        message: 'Количество не может быть отрицательным'
      });
    }
    
    console.log('💧 Сохранение воды:', {
      userId: req.userId,
      date,
      amount
    });
    
    const waterIntake = await Database.saveWaterIntake(req.userId, date, amount);
    
    console.log('✅ Вода сохранена:', waterIntake);
    
    res.json({
      success: true,
      message: 'Данные о воде сохранены',
      waterIntake
    });
  } catch (error) {
    console.error('Save water intake error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка сохранения данных о воде'
    });
  }
});

// AI совет по питанию
router.get('/ai-advice', authMiddleware, async (req, res) => {
  try {
    // 1. Получаем пользователя
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // 2. Получаем сегодняшние блюда
    const todayFoods = await Database.getFoodsByDate(req.userId, new Date());
    
    // 3. Получаем час из query или серверное время
    const hour = getLocalHour(req);
    
    // 4. Вызываем AI
    const result = await generateMealAdvice(user, todayFoods, hour);
    
    // 5. Возвращаем результат
    res.json({
      success: true,
      advice: result
    });
  } catch (error) {
    console.error('AI advice error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения AI совета'
    });
  }
});

module.exports = router;
