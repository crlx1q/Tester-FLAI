const express = require('express');
const multer = require('multer');
const authMiddleware = require('../middleware/auth');
const { checkFileSizeLimit, compressImage } = require('../middleware/image-compression');
const Database = require('../utils/database');
const { LIMITS } = require('../middleware/usage-limits');
const { getCurrentDate, getTodayStart, getLocalDay, getDaysDifference, TIMEZONE } = require('../utils/timezone');

const router = express.Router();

// Настройка multer для загрузки аватарки в файловую систему
const path = require('path');
const fs = require('fs');

// Создаем папку uploads/avatars если её нет
const avatarsDir = path.join(__dirname, '../uploads/avatars');
if (!fs.existsSync(avatarsDir)) {
  fs.mkdirSync(avatarsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, avatarsDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `avatar_${req.userId}_${Date.now()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const upload = multer({ 
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB временный лимит (будет проверяться в middleware)
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(file.originalname.toLowerCase());
    const mimetype = file.mimetype ? allowedTypes.test(file.mimetype) : true;
    
    if (mimetype || extname) {
      return cb(null, true);
    }
    cb(new Error('Только изображения разрешены!'));
  }
});

// Получить профиль
router.get('/', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем подписку и обновляем если истекла
    if (user.subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(user.subscriptionExpiresAt);
      
      // console.log('🔍 Проверка подписки (profile):', {
      //   now_Almaty: now.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   now_UTC: now.toISOString(),
      //   expiresAt_Almaty: expiresAt.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   expiresAt_UTC: expiresAt.toISOString(),
      //   expired: now > expiresAt
      // });
      
      if (now > expiresAt) {
        console.log('⚠️ Подписка истекла (profile), переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        // Обновляем данные пользователя
        user.subscriptionType = 'free';
        user.isPro = false;
        user.subscriptionExpiresAt = null;
      }
    }
    
    const userObject = user.toObject();
    delete userObject.password;
    
    // Добавляем оставшиеся дни подписки
    if (userObject.subscriptionType === 'pro' && userObject.subscriptionExpiresAt) {
      const StartupCheckService = require('../services/startup-check');
      userObject.subscriptionRemainingDays = StartupCheckService.calculateRemainingDays(userObject.subscriptionExpiresAt);
    }
    
    // Вычисляем статус streak
    const today = getTodayStart();
    const lastVisit = userObject.lastVisit ? new Date(userObject.lastVisit) : null;
    const lastVisitDay = lastVisit ? getLocalDay(lastVisit) : null;
    
    let streakStatus = 'inactive'; // inactive, active, at_risk, expired
    let displayStreak = userObject.streak || 0;
    
    if (lastVisitDay) {
      const diffDays = getDaysDifference(today, lastVisitDay);
      
      if (diffDays === 0) {
        // Сегодня была активность - горит
        streakStatus = 'active';
      } else if (diffDays === 1) {
        // Вчера была активность - серый (под угрозой)
        streakStatus = 'at_risk';
      } else {
        // Прошло 2+ дня - сгорел
        streakStatus = 'expired';
        displayStreak = 0;
      }
    } else {
      // Никогда не было активности
      streakStatus = 'inactive';
      displayStreak = 0;
    }
    
    userObject.streakStatus = streakStatus;
    userObject.displayStreak = displayStreak;
    
    res.json({
      success: true,
      user: userObject
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения профиля'
    });
  }
});

// Обновить профиль
router.put('/', authMiddleware, async (req, res) => {
  try {
    const updates = req.body;
    
    // Запрещаем изменять некоторые поля
    delete updates._id;
    delete updates.password;
    delete updates.email;
    
    // Валидация username при обновлении
    if (updates.username !== undefined) {
      const username = updates.username.toLowerCase().trim();
      if (username && !/^[a-z0-9_]{3,20}$/.test(username)) {
        return res.status(400).json({
          success: false,
          message: 'Username может содержать только латинские буквы, цифры и _ (3-20 символов)'
        });
      }
      if (username) {
        const existingUser = await Database.getUserByUsername(username);
        if (existingUser && existingUser._id.toString() !== req.userId) {
          return res.status(400).json({
            success: false,
            message: 'Этот username уже занят'
          });
        }
        updates.username = username;
      }
    }
    
    const updatedUser = await Database.updateUser(req.userId, updates);
    
    if (!updatedUser) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    const userObject = updatedUser.toObject();
    delete userObject.password;
    
    res.json({
      success: true,
      user: userObject
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления профиля'
    });
  }
});

// Сменить пароль
router.post('/change-password', authMiddleware, async (req, res) => {
  try {
    console.log('🔐 Запрос на смену пароля от пользователя:', req.userId);
    
    const { oldPassword, newPassword } = req.body;
    
    if (!oldPassword || !newPassword) {
      console.log('❌ Не указаны пароли');
      return res.status(400).json({
        success: false,
        message: 'Старый и новый пароль обязательны'
      });
    }
    
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Новый пароль должен быть не менее 6 символов'
      });
    }
    
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      console.log('❌ Пользователь не найден:', req.userId);
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    console.log('✅ Пользователь найден:', user.email);
    
    // Проверяем старый пароль
    const bcrypt = require('bcryptjs');
    const isValidPassword = await bcrypt.compare(oldPassword, user.password);
    
    if (!isValidPassword) {
      console.log('❌ Неверный старый пароль');
      return res.status(400).json({
        success: false,
        message: 'Неверный старый пароль'
      });
    }
    
    console.log('✅ Старый пароль верный');
    
    // Хешируем новый пароль
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    
    // Обновляем пароль
    await Database.updateUser(req.userId, { password: hashedPassword });
    
    console.log(`✅ Пароль пользователя ${req.userId} успешно изменен`);
    
    res.json({
      success: true,
      message: 'Пароль успешно изменен'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка смены пароля'
    });
  }
});

// Завершить онбординг
router.post('/onboarding', authMiddleware, async (req, res) => {
  try {
    const { goal, gender, age, height, weight, activityLevel, allergies } = req.body;
    
    // Рассчитываем базовый метаболизм и калории
    let bmr;
    if (gender === 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    
    // Коэффициенты активности
    const activityMultipliers = {
      low: 1.2,
      moderate: 1.5,
      high: 1.8
    };
    
    let dailyCalories = Math.round(bmr * activityMultipliers[activityLevel]);
    
    // Корректировка по цели
    if (goal === 'lose_weight') {
      dailyCalories = Math.round(dailyCalories * 0.85);
    } else if (goal === 'gain_muscle') {
      dailyCalories = Math.round(dailyCalories * 1.15);
    }
    
    // Рассчитываем макросы (примерное распределение)
    const macros = {
      protein: Math.round((dailyCalories * 0.3) / 4),
      fat: Math.round((dailyCalories * 0.25) / 9),
      carbs: Math.round((dailyCalories * 0.45) / 4)
    };
    
    const updates = {
      goal,
      gender,
      age,
      height,
      weight,
      activityLevel,
      allergies: allergies || [],
      dailyCalories,
      macros,
      onboardingCompleted: true
    };
    
    const updatedUser = await Database.updateUser(req.userId, updates);
    
    const userObject = updatedUser.toObject();
    delete userObject.password;
    
    res.json({
      success: true,
      user: userObject
    });
  } catch (error) {
    console.error('Onboarding error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка завершения онбординга'
    });
  }
});

// Получить информацию о лимитах и использовании
router.get('/limits', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем подписку и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    let isPro = subscriptionType === 'pro';
    let subscriptionExpiresAt = user.subscriptionExpiresAt;
    let remainingDays = 0;
    
    if (isPro && subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(subscriptionExpiresAt);
      
      // console.log('🔍 Проверка подписки (limits):', {
      //   now_Almaty: now.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   now_UTC: now.toISOString(),
      //   expiresAt_Almaty: expiresAt.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   expiresAt_UTC: expiresAt.toISOString(),
      //   expired: now > expiresAt
      // });
      
      if (now > expiresAt) {
        console.log('⚠️ Подписка истекла (limits), переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        isPro = false;
        subscriptionExpiresAt = null;
      } else {
        // Вычисляем оставшиеся дни
        const StartupCheckService = require('../services/startup-check');
        remainingDays = StartupCheckService.calculateRemainingDays(subscriptionExpiresAt);
      }
    }
    
    const usage = await Database.getUserUsage(req.userId);
    const limits = LIMITS[isPro ? 'pro' : 'free'];
    
    res.json({
      success: true,
      subscription: {
        type: isPro ? 'pro' : 'free',
        isPro,
        startedAt: user.subscriptionStartedAt,
        expiresAt: subscriptionExpiresAt,
        remainingDays: remainingDays
      },
      usage: {
        photos: {
          current: usage.photosCount,
          max: limits.photos,
          remaining: Math.max(0, limits.photos - usage.photosCount)
        },
        messages: {
          current: usage.messagesCount,
          max: limits.messages,
          remaining: Math.max(0, limits.messages - usage.messagesCount)
        },
        recipes: {
          current: usage.recipesCount,
          max: limits.recipes,
          remaining: Math.max(0, limits.recipes - usage.recipesCount)
        },
        mealAdvice: {
          current: usage.mealAdviceCount || 0,
          max: limits.mealAdvice,
          remaining: Math.max(0, limits.mealAdvice - (usage.mealAdviceCount || 0))
        },
        date: usage.date
      }
    });
  } catch (error) {
    console.error('Get limits error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения лимитов'
    });
  }
});

// Загрузить аватарку
router.post('/avatar', authMiddleware, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Файл не загружен'
      });
    }

    // Читаем файл и сжимаем
    const sharp = require('sharp');
    const imageBuffer = fs.readFileSync(req.file.path);
    
    // Сжимаем аватар (200x200, качество 80)
    const compressedBuffer = await sharp(imageBuffer)
      .resize(200, 200, { fit: 'cover' })
      .jpeg({ quality: 80, progressive: true })
      .toBuffer();
    
    // Удаляем временный файл
    fs.unlinkSync(req.file.path);
    
    // Обновляем пользователя с Buffer
    const updatedUser = await Database.updateUser(req.userId, { 
      avatar: compressedBuffer,
      avatarContentType: 'image/jpeg'
    });
    
    if (!updatedUser) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Возвращаем avatarUrl (виртуальное поле)
    const userObject = updatedUser.toObject();
    
    res.json({
      success: true,
      avatar: userObject.avatarUrl,
      message: 'Аватарка успешно загружена'
    });
  } catch (error) {
    console.error('Upload avatar error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка загрузки аватарки'
    });
  }
});

// Отменить подписку (перевести на FREE)
router.post('/cancel-subscription', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем, есть ли PRO подписка
    if (user.subscriptionType !== 'pro') {
      return res.status(400).json({
        success: false,
        message: 'У вас нет активной PRO подписки'
      });
    }
    
    // Переводим на FREE
    await Database.updateUserSubscription(user._id, 'free', null);
    
    console.log(`✅ Подписка отменена для пользователя ${req.userId} (${user.email})`);
    
    // Получаем обновленного пользователя
    const updatedUser = await Database.getUserById(req.userId);
    const userObject = updatedUser.toObject();
    delete userObject.password;
    
    res.json({
      success: true,
      message: 'Подписка успешно отменена',
      user: userObject
    });
  } catch (error) {
    console.error('Cancel subscription error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка отмены подписки'
    });
  }
});

// Удалить профиль
router.delete('/', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Изображения хранятся в MongoDB как Buffer, удаление файлов не требуется
    // Удаляем пользователя из базы (это также удалит все его данные через каскадное удаление)
    const deleted = await Database.deleteUser(req.userId);
    
    console.log(`✅ Профиль пользователя ${req.userId} полностью удален`);
    
    res.json({
      success: true,
      message: 'Профиль успешно удален'
    });
  } catch (error) {
    console.error('Delete profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления профиля'
    });
  }
});

module.exports = router;
