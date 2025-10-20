const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Database = require('../utils/database');

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
    
    // Добавляем информацию о текущем использовании для каждого пользователя
    const usersWithUsage = await Promise.all(users.map(async user => {
      const usage = await Database.getUserUsage(user._id);
      return {
        ...user,
        currentUsage: usage
      };
    }));
    
    res.json({
      success: true,
      users: usersWithUsage
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
      const expirationDate = new Date();
      expirationDate.setDate(expirationDate.getDate() + parseInt(durationDays));
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
    const today = new Date().toISOString().split('T')[0];
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

// Загрузить APK файл
router.post('/upload-apk', checkAdminAuth, uploadApk.single('apk'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'APK файл не загружен'
      });
    }
    
    res.json({
      success: true,
      message: 'APK файл успешно загружен',
      filename: req.file.filename,
      path: '/apk/app-release.apk'
    });
  } catch (error) {
    console.error('Upload APK error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка загрузки APK файла'
    });
  }
});

module.exports = router;
