const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const authMiddleware = require('../middleware/auth');
const { checkPhotoLimit } = require('../middleware/usage-limits');
const { checkFileSizeLimit, compressImage, compressBase64Image, checkBase64SizeLimit } = require('../middleware/image-compression');
const User = require('../models/User');
const Food = require('../models/Food');
const { analyzeFood } = require('../services/ai-service');
const { compressFoodImage, bufferToBase64 } = require('../utils/imageUtils');

const router = express.Router();

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
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Анализируем изображение через AI
    const analysis = await analyzeFood(req.file.path, user);
    
    // Определяем тип приема пищи по времени
    const hour = new Date().getHours();
    let mealType = 'snack';
    if (hour >= 6 && hour < 11) mealType = 'breakfast';
    else if (hour >= 11 && hour < 16) mealType = 'lunch';
    else if (hour >= 16 && hour < 22) mealType = 'dinner';
    
    // Сжимаем изображение для хранения в MongoDB
    const compressedImage = await compressFoodImage(req.file.path);
    
    // Создаем новую запись о еде
    const newFood = new Food({
      userId: user._id,
      name: (analysis.name && analysis.name.trim() !== '') ? analysis.name : 'Блюдо',
      calories: analysis.calories || 0,
      macros: analysis.macros || { protein: 0, fat: 0, carbs: 0 },
      meal: mealType,
      image: compressedImage,
      date: new Date(),
      aiConfidence: analysis.confidence || 0.8,
      portion: {
        size: 1,
        unit: 'порция'
      }
    });
    
    await newFood.save();
    
    // Удаляем временный файл
    if (fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    
    // Подготавливаем ответ с base64 изображением
    const responseFood = newFood.toObject();
    if (responseFood.image && responseFood.image.data) {
      responseFood.imageBase64 = bufferToBase64(responseFood.image.data, responseFood.image.contentType);
      delete responseFood.image; // Удаляем бинарные данные из ответа
    }
    
    console.log('📸 Сохранено блюдо в MongoDB:', responseFood.name);
    
    res.json({
      success: true,
      food: responseFood
    });
  } catch (error) {
    console.error('Food analysis error:', error);
    
    // Удаляем временный файл в случае ошибки
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({
      success: false,
      message: error.message || 'Ошибка анализа изображения'
    });
  }
});

// История еды
router.get('/history', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    
    const foods = await Food.find({ userId: req.userId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip);
    
    // Подготавливаем ответ с base64 изображениями
    const foodsWithImages = foods.map(food => {
      const foodObj = food.toObject();
      if (foodObj.image && foodObj.image.data) {
        foodObj.imageBase64 = bufferToBase64(foodObj.image.data, foodObj.image.contentType);
        delete foodObj.image;
      }
      return foodObj;
    });
    
    const totalCount = await Food.countDocuments({ userId: req.userId });
    
    res.json({
      success: true,
      foods: foodsWithImages,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit),
        totalItems: totalCount,
        hasNext: page * limit < totalCount,
        hasPrev: page > 1
      }
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
    const user = await User.findById(req.userId);
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
    
    const dayFoods = await Food.getUserFoodsByDate(req.userId, targetDate);
    
    // Подсчитываем калории и макросы с учетом порций
    let totalCalories = 0;
    let consumedMacros = { carbs: 0, protein: 0, fat: 0 };
    
    const foodsWithImages = dayFoods.map(food => {
      const portionSize = food.portion?.size || 1;
      totalCalories += (food.calories || 0) * portionSize;
      
      if (food.macros) {
        consumedMacros.carbs += (food.macros.carbs || 0) * portionSize;
        consumedMacros.protein += (food.macros.protein || 0) * portionSize;
        consumedMacros.fat += (food.macros.fat || 0) * portionSize;
      }
      
      // Подготавливаем изображение для ответа
      const foodObj = food.toObject();
      if (foodObj.image && foodObj.image.data) {
        foodObj.imageBase64 = bufferToBase64(foodObj.image.data, foodObj.image.contentType);
        delete foodObj.image;
      }
      return foodObj;
    });
    
    const remainingCalories = user.dailyCalorieGoal - totalCalories;
    
    // Группируем по типам приема пищи
    const mealGroups = {
      breakfast: foodsWithImages.filter(f => f.meal === 'breakfast'),
      lunch: foodsWithImages.filter(f => f.meal === 'lunch'),
      dinner: foodsWithImages.filter(f => f.meal === 'dinner'),
      snack: foodsWithImages.filter(f => f.meal === 'snack')
    };
    
    res.json({
      success: true,
      data: {
        totalCalories: Math.round(totalCalories),
        targetCalories: user.dailyCalorieGoal,
        remainingCalories: Math.round(remainingCalories),
        consumedMacros: {
          carbs: Math.round(consumedMacros.carbs),
          protein: Math.round(consumedMacros.protein),
          fat: Math.round(consumedMacros.fat)
        },
        foods: foodsWithImages,
        mealGroups,
        date: targetDate.toISOString().split('T')[0]
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
router.get('/weekly-progress', authMiddleware, (req, res) => {
  try {
    const user = Database.getUserById(req.userId);
    const weekData = [];
    
    // Получаем данные за последние 7 дней
    for (let i = 6; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      date.setHours(0, 0, 0, 0);
      
      const dayFoods = Database.getFoodsByDate(req.userId, date);
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
router.get('/monthly-active-days', authMiddleware, (req, res) => {
  try {
    const { year, month } = req.query;
    
    if (!year || !month) {
      return res.status(400).json({
        success: false,
        message: 'Год и месяц обязательны'
      });
    }
    
    // Используем UTC даты для корректной работы с часовыми поясами
    const startDate = new Date(Date.UTC(parseInt(year), parseInt(month) - 1, 1));
    const endDate = new Date(Date.UTC(parseInt(year), parseInt(month), 0, 23, 59, 59, 999));
    
    const activeDays = [];
    const currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      const foods = Database.getFoodsByDate(req.userId, currentDate);
      if (foods && foods.length > 0) {
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
router.put('/:id', authMiddleware, (req, res) => {
  try {
    const food = Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId !== req.userId) {
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
    
    const updatedFood = Database.updateFood(req.params.id, {
      name,
      calories,
      macros,
      healthScore
    });
    
    console.log('✅ Блюдо обновлено:', updatedFood);
    
    res.json({
      success: true,
      message: 'Блюдо успешно обновлено',
      food: updatedFood
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
    const food = Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId !== req.userId) {
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
    
    // Обновляем блюдо
    const updatedFood = Database.updateFood(req.params.id, {
      name: foodData.name || newName,
      calories: foodData.calories || 0,
      macros: foodData.macros || { protein: 0, fat: 0, carbs: 0 },
      healthScore: foodData.healthScore !== undefined ? foodData.healthScore : 50
    });
    
    console.log('✅ Блюдо обновлено:', updatedFood);
    
    res.json({
      success: true,
      message: 'Блюдо успешно обновлено с учетом фото',
      food: updatedFood,
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
router.delete('/:id', authMiddleware, (req, res) => {
  try {
    const food = Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет доступа к этому блюду'
      });
    }
    
    // Удаляем изображение если есть
    if (food.imageUrl) {
      const fs = require('fs');
      const imagePath = path.join(__dirname, '..', food.imageUrl);
      if (fs.existsSync(imagePath)) {
        try {
          fs.unlinkSync(imagePath);
          console.log(`🗑️ Удалено изображение: ${imagePath}`);
        } catch (err) {
          console.error('Ошибка удаления изображения:', err);
        }
      }
    }
    
    const deletedFood = Database.deleteFood(req.params.id);
    
    res.json({
      success: true,
      message: 'Блюдо успешно удалено',
      food: deletedFood
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
router.post('/:id/favorite', authMiddleware, (req, res) => {
  try {
    const food = Database.getFoodById(req.params.id);
    
    if (!food) {
      return res.status(404).json({
        success: false,
        message: 'Блюдо не найдено'
      });
    }
    
    // Проверяем, что блюдо принадлежит текущему пользователю
    if (food.userId !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет доступа к этому блюду'
      });
    }
    
    const favoriteFood = Database.addFavoriteFood(req.userId, {
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
router.get('/favorites/list', authMiddleware, (req, res) => {
  try {
    const favoriteFoods = Database.getFavoriteFoods(req.userId);
    
    res.json({
      success: true,
      favoriteFoods
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
router.delete('/favorites/:id', authMiddleware, (req, res) => {
  try {
    const deletedFood = Database.removeFavoriteFood(req.userId, req.params.id);
    
    if (!deletedFood) {
      return res.status(404).json({
        success: false,
        message: 'Избранное блюдо не найдено'
      });
    }
    
    res.json({
      success: true,
      message: 'Блюдо удалено из избранного',
      food: deletedFood
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
router.post('/favorites/:id/add-to-diary', authMiddleware, (req, res) => {
  try {
    const favoriteFoods = Database.getFavoriteFoods(req.userId);
    const favoriteFood = favoriteFoods.find(f => f._id === req.params.id);
    
    if (!favoriteFood) {
      return res.status(404).json({
        success: false,
        message: 'Избранное блюдо не найдено'
      });
    }
    
    // Определяем тип приема пищи по времени
    const hour = new Date().getHours();
    let mealType = 'Перекус';
    if (hour >= 6 && hour < 11) mealType = 'Завтрак';
    else if (hour >= 11 && hour < 16) mealType = 'Обед';
    else if (hour >= 16 && hour < 22) mealType = 'Ужин';
    
    // Создаем новое блюдо в дневнике
    const foodData = {
      userId: req.userId,
      name: favoriteFood.name,
      imageUrl: null, // Избранное без фото
      calories: favoriteFood.calories,
      macros: favoriteFood.macros,
      mealType
    };
    
    const newFood = Database.createFood(foodData);
    
    res.json({
      success: true,
      message: 'Блюдо добавлено в дневник',
      food: newFood
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
    
    // Определяем тип приема пищи по времени
    const hour = new Date().getHours();
    let mealType = 'Перекус';
    if (hour >= 6 && hour < 11) mealType = 'Завтрак';
    else if (hour >= 11 && hour < 16) mealType = 'Обед';
    else if (hour >= 16 && hour < 22) mealType = 'Ужин';
    
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
    const user = Database.getUserById(req.userId);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? new Date(lastVisit.getFullYear(), lastVisit.getMonth(), lastVisit.getDate()) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    
    if (lastVisitDay) {
      const diffDays = Math.floor((today - lastVisitDay) / (1000 * 60 * 60 * 24));
      if (diffDays === 0) {
        // Сегодня уже была активность
      } else if (diffDays === 1) {
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
      } else {
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
      }
    } else {
      newStreak = 1;
      maxStreak = 1;
    }
    
    Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
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
    
    // Проверяем размер для free пользователей
    try {
      checkBase64SizeLimit(req.userId, base64Data);
    } catch (error) {
      if (error.statusCode === 413) {
        return res.status(413).json({
          success: false,
          message: error.message,
          fileSize: error.fileSize
        });
      }
      throw error;
    }
    
    // Сжимаем изображение
    const compressedBuffer = await compressBase64Image(base64Data);
    base64Data = compressedBuffer.toString('base64');

    const { analyzeImageFood } = require('../utils/ai');
    
    // Анализируем через Gemini Vision
    const foodData = await analyzeImageFood(base64Data);
    
    console.log('📊 AI Analysis Result:', JSON.stringify(foodData, null, 2));
    
    // Сохраняем изображение на диск
    const fs = require('fs');
    const path = require('path');
    const uploadDir = 'uploads/food';
    
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    const filename = `food-${Date.now()}-${req.userId}.jpg`;
    const filepath = path.join(uploadDir, filename);
    
    // Сохраняем base64 как файл
    fs.writeFileSync(filepath, Buffer.from(base64Data, 'base64'));
    
    const imageUrl = `/uploads/food/${filename}`;
    
    // Определяем тип приема пищи по времени
    const hour = new Date().getHours();
    let mealType = 'Перекус';
    if (hour >= 6 && hour < 11) mealType = 'Завтрак';
    else if (hour >= 11 && hour < 16) mealType = 'Обед';
    else if (hour >= 16 && hour < 22) mealType = 'Ужин';
    
    // Добавляем блюдо в дневник (БЕЗ эмодзи, только название)
    const name = foodData.name || 'Неизвестное блюдо';
    const foodToSave = {
      userId: req.userId,
      name: name, // Без эмодзи!
      calories: foodData.calories || 0,
      macros: foodData.macros || { protein: 0, fat: 0, carbs: 0 },
      healthScore: foodData.healthScore !== undefined ? foodData.healthScore : 50,
      imageUrl: imageUrl, // Сохраняем путь к фото
      mealType
    };
    
    console.log('💾 Saving food to database:', JSON.stringify(foodToSave, null, 2));
    const newFood = Database.createFood(foodToSave);
    console.log('✅ Food saved:', JSON.stringify(newFood, null, 2));
    
    // Увеличиваем счетчик использования
    Database.incrementUserUsage(req.userId, 'photos');
    
    // Обновляем streak (активность пользователя)
    const user = Database.getUserById(req.userId);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? new Date(lastVisit.getFullYear(), lastVisit.getMonth(), lastVisit.getDate()) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    
    if (lastVisitDay) {
      const diffDays = Math.floor((today - lastVisitDay) / (1000 * 60 * 60 * 24));
      if (diffDays === 0) {
        // Сегодня уже была активность
      } else if (diffDays === 1) {
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
      } else {
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
      }
    } else {
      newStreak = 1;
      maxStreak = 1;
    }
    
    Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
    res.json({ 
      success: true, 
      food: newFood,
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
router.get('/water/:date', authMiddleware, (req, res) => {
  try {
    const { date } = req.params;
    
    if (!date) {
      return res.status(400).json({
        success: false,
        message: 'Дата обязательна'
      });
    }
    
    const waterIntake = Database.getWaterIntakeByDate(req.userId, date);
    
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
router.post('/water', authMiddleware, (req, res) => {
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
    
    const waterIntake = Database.saveWaterIntake(req.userId, date, amount);
    
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

module.exports = router;
