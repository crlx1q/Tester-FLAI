const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Database = require('../utils/database');

const router = express.Router();

// Регистрация
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // Проверка, включена ли регистрация
    const appSettings = await Database.getAppSettings();
    if (!appSettings.registrationEnabled) {
      return res.status(403).json({
        success: false,
        message: 'Регистрация временно отключена'
      });
    }
    
    // Валидация
    if (!email || !password || !name) {
      return res.status(400).json({
        success: false,
        message: 'Все поля обязательны'
      });
    }
    
    // Проверка существующего пользователя
    const existingUser = await Database.getUserByEmail(email);
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Пользователь с таким email уже существует'
      });
    }
    
    // Хеширование пароля
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Создание пользователя
    const newUser = await Database.createUser({
      email,
      password: hashedPassword,
      name,
      subscriptionType: 'free',
      isPro: false,
      subscriptionExpiresAt: null,
      streak: 0,
      onboardingCompleted: false,
      allergies: [],
      dailyCalories: 2000,
      macros: {
        carbs: 270,
        protein: 130,
        fat: 58
      }
    });
    
    // Создание токена
    const token = jwt.sign(
      { userId: newUser._id.toString() },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    
    // Удаляем пароль из ответа (конвертируем Mongoose документ в объект)
    const userObject = newUser.toObject();
    delete userObject.password;
    
    res.status(201).json({
      success: true,
      token,
      user: userObject
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка при регистрации'
    });
  }
});

// Вход
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Валидация
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email и пароль обязательны'
      });
    }
    
    // Поиск пользователя
    const user = await Database.getUserByEmail(email);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Неверный email или пароль'
      });
    }
    
    // Проверка пароля
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Неверный email или пароль'
      });
    }
    
    // Создание токена
    const token = jwt.sign(
      { userId: user._id.toString() },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    
    // Удаляем пароль из ответа (конвертируем Mongoose документ в объект)
    const userObject = user.toObject();
    delete userObject.password;
    
    res.json({
      success: true,
      token,
      user: userObject
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка при входе'
    });
  }
});

// Проверка версии приложения
router.post('/check-version', async (req, res) => {
  try {
    const { currentVersion } = req.body;
    
    if (!currentVersion) {
      return res.status(400).json({
        success: false,
        message: 'Версия приложения не указана'
      });
    }
    
    const appSettings = await Database.getAppSettings();
    const serverVersion = appSettings.currentVersion;
    
    // Сравниваем версии
    const needsUpdate = compareVersions(currentVersion, serverVersion) < 0;
    
    res.json({
      success: true,
      needsUpdate,
      currentVersion: serverVersion,
      updateDescription: appSettings.updateDescription || '',
      downloadUrl: needsUpdate ? '/apk/app-release.apk' : null
    });
  } catch (error) {
    console.error('Check version error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка проверки версии'
    });
  }
});

// Функция сравнения версий (возвращает -1 если v1 < v2, 0 если равны, 1 если v1 > v2)
function compareVersions(v1, v2) {
  const parts1 = v1.split('.').map(Number);
  const parts2 = v2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const part1 = parts1[i] || 0;
    const part2 = parts2[i] || 0;
    
    if (part1 < part2) return -1;
    if (part1 > part2) return 1;
  }
  
  return 0;
}

module.exports = router;
