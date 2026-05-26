const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Database = require('../utils/database-mongo');
const { sendPushToMany } = require('../services/firebase');
const User = require('../models/User');

const router = express.Router();

// Настройка multer для загрузки APK
const apkStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const apkDir = path.join(__dirname, '../apk');
    if (!fs.existsSync(apkDir)) {
      fs.mkdirSync(apkDir, { recursive: true });
    }
    cb(null, apkDir);
  },
  filename: (req, file, cb) => {
    cb(null, 'app-release.apk');
  }
});

const uploadApk = multer({ 
  storage: apkStorage,
  fileFilter: (req, file, cb) => {
    if (path.extname(file.originalname).toLowerCase() === '.apk') {
      cb(null, true);
    } else {
      cb(new Error('Только APK файлы разрешены'));
    }
  }
});

// Простая авторизация для админки (в реальном проекте используйте более безопасный метод)
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

const checkAdminAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Требуется авторизация'
    });
  }
  
  const password = authHeader.substring(7);
  if (password !== ADMIN_PASSWORD) {
    return res.status(403).json({
      success: false,
      message: 'Неверный пароль'
    });
  }
  
  next();
};

// Авторизация админа
router.post('/auth', (req, res) => {
  const { password } = req.body;
  
  if (password === ADMIN_PASSWORD) {
    res.json({
      success: true,
      token: password
    });
  } else {
    res.status(401).json({
      success: false,
      message: 'Неверный пароль'
    });
  }
});

// Получить всех пользователей
router.get('/users', checkAdminAuth, async (req, res) => {
  try {
    const users = await Database.getAllUsersForAdmin();
    const StartupCheckService = require('../services/startup-check');
    
    // Преобразуем Mongoose документы в обычные объекты
    const usersData = users.map(user => {
      const userObj = user.toObject ? user.toObject() : user;
      
      // Добавляем оставшиеся дни подписки
      if (userObj.subscriptionType === 'pro' && userObj.subscriptionExpiresAt) {
        userObj.subscriptionRemainingDays = StartupCheckService.calculateRemainingDays(userObj.subscriptionExpiresAt);
      } else {
        userObj.subscriptionRemainingDays = 0;
      }
      
      return userObj;
    });
    
    res.json({
      success: true,
      users: usersData
    });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения пользователей'
    });
  }
});

// Выдать/обновить подписку пользователю
router.post('/users/:userId/subscription', checkAdminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { subscriptionType, durationDays } = req.body;
    
    if (!['free', 'pro'].includes(subscriptionType)) {
      return res.status(400).json({
        success: false,
        message: 'Неверный тип подписки. Используйте "free" или "pro"'
      });
    }
    
    let expiresAt = null;
    if (subscriptionType === 'pro' && durationDays) {
      const { getTodayStart } = require('../utils/timezone');
      const today = getTodayStart(); // Начало дня в Asia/Almaty (в UTC)
      // Добавляем дни напрямую в миллисекундах, чтобы избежать проблем с часовыми поясами
      const daysInMs = parseInt(durationDays) * 24 * 60 * 60 * 1000;
      const expirationDate = new Date(today.getTime() + daysInMs);
      expiresAt = expirationDate.toISOString();
    }
    
    const updatedUser = await Database.updateUserSubscription(userId, subscriptionType, expiresAt);
    
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
      message: `Подписка ${subscriptionType} успешно ${subscriptionType === 'pro' ? 'выдана на ' + durationDays + ' дней' : 'установлена'}`,
      user: userObject
    });
  } catch (error) {
    console.error('Update subscription error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления подписки'
    });
  }
});

// Получить статистику по использованию
router.get('/stats', checkAdminAuth, async (req, res) => {
  try {
    const users = await Database.getAllUsersForAdmin();
    
    const stats = {
      totalUsers: users.length,
      freeUsers: users.filter(u => !u.subscriptionType || u.subscriptionType === 'free').length,
      proUsers: users.filter(u => u.subscriptionType === 'pro').length,
      todayActivity: {
        totalPhotos: 0,
        totalMessages: 0,
        totalRecipes: 0
      }
    };
    
    // Подсчитываем активность за сегодня
    const { getDateString, getCurrentDate } = require('../utils/timezone');
    const today = getDateString(getCurrentDate());
    users.forEach(user => {
      if (user.usage && user.usage.date === today) {
        stats.todayActivity.totalPhotos += user.usage.photosCount || 0;
        stats.todayActivity.totalMessages += user.usage.messagesCount || 0;
        stats.todayActivity.totalRecipes += user.usage.recipesCount || 0;
      }
    });
    
    res.json({
      success: true,
      stats
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения статистики'
    });
  }
});

// Полное удаление пользователя
router.delete('/users/:userId', checkAdminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    
    const deletedUser = await Database.deleteUserCompletely(userId);
    
    if (!deletedUser) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    res.json({
      success: true,
      message: `Пользователь ${deletedUser.name} и все его данные удалены`
    });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления пользователя'
    });
  }
});

// Получить настройки приложения
router.get('/settings', checkAdminAuth, async (req, res) => {
  try {
    const settings = await Database.getAppSettings();
    res.json({
      success: true,
      settings
    });
  } catch (error) {
    console.error('Get settings error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения настроек'
    });
  }
});

// Переключить регистрацию
router.post('/settings/toggle-registration', checkAdminAuth, async (req, res) => {
  try {
    const settings = await Database.getAppSettings();
    const updatedSettings = await Database.updateAppSettings({
      registrationEnabled: !settings.registrationEnabled
    });
    
    res.json({
      success: true,
      message: `Регистрация ${updatedSettings.registrationEnabled ? 'включена' : 'отключена'}`,
      settings: updatedSettings
    });
  } catch (error) {
    console.error('Toggle registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка переключения регистрации'
    });
  }
});

// Обновить версию приложения
router.post('/settings/update-version', checkAdminAuth, async (req, res) => {
  try {
    const { version, description } = req.body;
    
    if (!version) {
      return res.status(400).json({
        success: false,
        message: 'Версия обязательна'
      });
    }
    
    const updatedSettings = await Database.updateAppSettings({
      currentVersion: version,
      updateDescription: description || '',
      hasUpdate: true
    });
    
    // Send push notification to all users who have updates enabled
    try {
      const usersWithUpdates = await User.find({
        fcmToken: { $ne: null, $exists: true },
        'notificationSettings.updates': { $ne: false }
      }).select('fcmToken').lean();
      
      if (usersWithUpdates.length > 0) {
        await sendPushToMany(
          usersWithUpdates,
          'Новое обновление FoodLens AI',
          `Доступна версия ${version}. ${description || 'Обновите приложение!'}`,
          { type: 'app_update', version }
        );
        console.log(`Update notification sent to ${usersWithUpdates.length} users`);
      }
    } catch (pushError) {
      console.error('Update push error:', pushError.message);
    }
    
    res.json({
      success: true,
      message: `Версия обновлена до ${version}`,
      settings: updatedSettings
    });
  } catch (error) {
    console.error('Update version error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления версии'
    });
  }
});

// Загрузить APK файл с прогрессом
router.post('/upload-apk', checkAdminAuth, (req, res) => {
  try {
    const busboy = require('busboy');
    const bb = busboy({ headers: req.headers });
    
    let totalBytes = 0;
    let uploadedBytes = 0;
    const apkPath = path.join(__dirname, '../apk/app-release.apk');
    
    // Получаем размер файла из заголовка
    const contentLength = parseInt(req.headers['content-length'] || '0');
    
    bb.on('file', (fieldname, file, info) => {
      const { filename, encoding, mimeType } = info;
      
      console.log(`📦 Начало загрузки APK: ${filename} (${(contentLength / 1024 / 1024).toFixed(2)} MB)`);
      
      // Создаем директорию если не существует
      const apkDir = path.dirname(apkPath);
      if (!fs.existsSync(apkDir)) {
        fs.mkdirSync(apkDir, { recursive: true });
      }
      
      const writeStream = fs.createWriteStream(apkPath);
      
      file.on('data', (data) => {
        uploadedBytes += data.length;
      });
      
      file.pipe(writeStream);
      
      writeStream.on('finish', () => {
        console.log('✅ APK файл успешно загружен');
      });
    });
    
    bb.on('finish', () => {
      res.json({
        success: true,
        message: 'APK файл успешно загружен',
        filename: 'app-release.apk',
        path: '/apk/app-release.apk',
        size: uploadedBytes
      });
    });
    
    bb.on('error', (error) => {
      console.error('Upload error:', error);
      res.status(500).json({
        success: false,
        message: 'Ошибка загрузки APK файла'
      });
    });
    
    req.pipe(bb);
  } catch (error) {
    console.error('Upload APK error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка загрузки APK файла'
    });
  }
});

// Скачать APK файл (публичный маршрут)
router.get('/download-apk', (req, res) => {
  try {
    const apkPath = path.join(__dirname, '../apk/app-release.apk');
    
    if (!fs.existsSync(apkPath)) {
      return res.status(404).json({
        success: false,
        message: 'APK файл не найден'
      });
    }
    
    res.download(apkPath, 'FoodLens-AI.apk', (err) => {
      if (err) {
        console.error('Download error:', err);
        res.status(500).json({
          success: false,
          message: 'Ошибка скачивания APK'
        });
      }
    });
  } catch (error) {
    console.error('Download APK error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка скачивания APK файла'
    });
  }
});

// Обновить Gemini API ключ
router.post('/settings/gemini-api-key', checkAdminAuth, async (req, res) => {
  try {
    const { apiKey } = req.body;
    
    if (!apiKey || apiKey.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'API ключ обязателен'
      });
    }
    
    // Сохраняем API ключ в БД (в открытом виде, но не отдаем клиенту)
    const updatedSettings = await Database.updateAppSettings({
      geminiApiKey: apiKey
    });
    
    // Также обновляем переменную окружения для текущего процесса
    process.env.GEMINI_API_KEY = apiKey;
    
    console.log('✅ Gemini API ключ обновлен');
    
    res.json({
      success: true,
      message: 'Gemini API ключ успешно сохранен',
      keyPreview: apiKey.substring(0, 8) + '...' + apiKey.slice(-4) // Показываем только начало и конец
    });
  } catch (error) {
    console.error('Update Gemini API key error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка сохранения API ключа'
    });
  }
});

// Проверить наличие Gemini API ключа
router.get('/settings/gemini-api-key/status', checkAdminAuth, async (req, res) => {
  try {
    const settings = await Database.getAppSettings();
    
    res.json({
      success: true,
      hasKey: !!settings.geminiApiKey,
      keyPreview: settings.geminiApiKey 
        ? settings.geminiApiKey.substring(0, 8) + '...' + settings.geminiApiKey.slice(-4)
        : null
    });
  } catch (error) {
    console.error('Get Gemini API key status error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения статуса API ключа'
    });
  }
});

module.exports = router;
