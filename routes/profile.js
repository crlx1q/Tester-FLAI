const express = require('express');
const multer = require('multer');
const authMiddleware = require('../middleware/auth');
const { checkFileSizeLimit, compressImage } = require('../middleware/image-compression');
const Database = require('../utils/database');
const { LIMITS } = require('../middleware/usage-limits');

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
    
    const userObject = user.toObject();
    delete userObject.password;
    
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
    
    if (isPro && subscriptionExpiresAt) {
      const expiresAt = new Date(subscriptionExpiresAt);
      const now = new Date();
      if (now > expiresAt) {
        await Database.updateUserSubscription(user._id, 'free', null);
        isPro = false;
        subscriptionExpiresAt = null;
      }
    }
    
    const usage = await Database.getUserUsage(req.userId);
    const limits = LIMITS[isPro ? 'pro' : 'free'];
    
    res.json({
      success: true,
      subscription: {
        type: isPro ? 'pro' : 'free',
        isPro,
        expiresAt: subscriptionExpiresAt
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
router.post('/avatar', authMiddleware, upload.single('avatar'), checkFileSizeLimit, compressImage, async (req, res) => {
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
