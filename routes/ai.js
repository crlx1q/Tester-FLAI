const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const authMiddleware = require('../middleware/auth');
const { checkMessageLimit, requirePro } = require('../middleware/usage-limits');
const { checkFileSizeLimit, compressImage } = require('../middleware/image-compression');
const Database = require('../utils/database');
const { chatWithAI, chatWithAIImage } = require('../services/ai-service');

const router = express.Router();

// Настройка multer для загрузки изображений
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads/chat/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `chat-${Date.now()}${path.extname(file.originalname)}`);
  }
});

const upload = multer({ 
  storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB временный лимит (будет проверяться в middleware)
});

// AI Чат
router.post('/chat', authMiddleware, checkMessageLimit, async (req, res) => {
  try {
    const { message, chatHistory } = req.body;
    
    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Сообщение не может быть пустым'
      });
    }
    
    // Получаем контекст пользователя
    const user = await Database.getUserById(req.userId);
    const todayFoods = await Database.getFoodsByDate(req.userId, new Date());
    
    // Формируем контекст для AI
    const context = {
      user: {
        name: user.name,
        age: user.age,
        height: user.height,
        weight: user.weight,
        gender: user.gender,
        goal: user.goal,
        activityLevel: user.activityLevel,
        targetWeight: user.targetWeight,
        dailyCalories: user.dailyCalories,
        macros: user.macros,
        allergies: user.allergies,
        waterTarget: user.waterTarget
      },
      todayFoods: todayFoods.map(f => ({
        name: f.name,
        calories: f.calories,
        macros: f.macros,
        mealType: f.mealType
      })),
      chatHistory: chatHistory || []
    };
    
    // Получаем ответ от AI
    const response = await chatWithAI(message, context);
    
    // Увеличиваем счетчик использования
    await Database.incrementUserUsage(req.userId, 'messages');
    
    // Обновляем streak (активность пользователя)
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
    
    await Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
    res.json({
      success: true,
      response
    });
  } catch (error) {
    console.error('AI chat error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обработки запроса AI'
    });
  }
});

// AI Чат с изображением
router.post('/chat-image', authMiddleware, checkMessageLimit, upload.single('image'), async (req, res) => {
  try {
    const { message, chatHistory } = req.body;
    
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Изображение не загружено'
      });
    }
    
    // Сжимаем изображение вручную
    const sharp = require('sharp');
    const fs = require('fs');
    const imageBuffer = fs.readFileSync(req.file.path);
    const compressedBuffer = await sharp(imageBuffer)
      .resize(1024, 1024, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();
    
    // Перезаписываем файл сжатым
    fs.writeFileSync(req.file.path, compressedBuffer);
    
    // Получаем контекст пользователя
    const user = await Database.getUserById(req.userId);
    const todayFoods = await Database.getFoodsByDate(req.userId, new Date());
    
    // Формируем контекст для AI
    const context = {
      user: {
        name: user.name,
        age: user.age,
        height: user.height,
        weight: user.weight,
        gender: user.gender,
        goal: user.goal,
        activityLevel: user.activityLevel,
        targetWeight: user.targetWeight,
        dailyCalories: user.dailyCalories,
        macros: user.macros,
        allergies: user.allergies,
        waterTarget: user.waterTarget
      },
      todayFoods: todayFoods.map(f => ({
        name: f.name,
        calories: f.calories,
        macros: f.macros,
        mealType: f.mealType
      })),
      chatHistory: chatHistory ? JSON.parse(chatHistory) : []
    };
    
    // Получаем ответ от AI с анализом изображения
    const response = await chatWithAIImage(req.file.path, message, context);
    
    // Увеличиваем счетчик использования
    await Database.incrementUserUsage(req.userId, 'messages');
    
    // Обновляем streak (активность пользователя)
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
    
    await Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
    // Удаляем временный файл
    fs.unlinkSync(req.file.path);
    
    res.json({
      success: true,
      response
    });
  } catch (error) {
    console.error('AI chat with image error:', error);
    // Удаляем файл в случае ошибки
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    res.status(500).json({
      success: false,
      message: 'Ошибка обработки изображения'
    });
  }
});

// AI дневная сводка (только для Pro)
router.post('/daily-summary', authMiddleware, requirePro, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    const todayFoods = await Database.getFoodsByDate(req.userId, new Date());
    
    // Подсчитываем общие показатели
    let totalCalories = 0;
    let totalMacros = { protein: 0, fat: 0, carbs: 0 };
    
    todayFoods.forEach(food => {
      totalCalories += food.calories || 0;
      if (food.macros) {
        totalMacros.protein += food.macros.protein || 0;
        totalMacros.fat += food.macros.fat || 0;
        totalMacros.carbs += food.macros.carbs || 0;
      }
    });
    
    // Формируем запрос к AI для анализа дня
    const summaryPrompt = `
Проанализируй мой день питания и дай детальную сводку с рекомендациями.

Информация о пользователе:
- Цель: ${user.goal === 'lose_weight' ? 'Похудение' : user.goal === 'gain_muscle' ? 'Набор мышечной массы' : 'Поддержание веса'}
- Целевые калории: ${user.dailyCalories} ккал
- Целевые макросы: Б-${user.macros?.protein}г, Ж-${user.macros?.fat}г, У-${user.macros?.carbs}г
${user.allergies && user.allergies.length > 0 ? `- Аллергии: ${user.allergies.join(', ')}` : ''}

Сегодня съедено:
- Калории: ${totalCalories} ккал
- Макросы: Б-${Math.round(totalMacros.protein)}г, Ж-${Math.round(totalMacros.fat)}г, У-${Math.round(totalMacros.carbs)}г
- Блюда (${todayFoods.length}): ${todayFoods.map(f => f.name).join(', ')}

Дай подробный анализ:
1. Оценка достижения целей (калории и макросы)
2. Баланс питания и качество блюд
3. Конкретные рекомендации на завтра
4. Что добавить/убрать из рациона

Ответ должен быть структурированным, мотивирующим и персонализированным.`;

    const { chatWithAI } = require('../services/ai-service');
    const summary = await chatWithAI(summaryPrompt, { user, todayFoods });
    
    res.json({
      success: true,
      summary,
      stats: {
        totalCalories,
        targetCalories: user.dailyCalories,
        totalMacros,
        targetMacros: user.macros,
        foodsCount: todayFoods.length
      }
    });
  } catch (error) {
    console.error('Daily summary error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка создания дневной сводки'
    });
  }
});

module.exports = router;
