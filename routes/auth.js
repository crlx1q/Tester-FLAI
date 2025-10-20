const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

// Регистрация
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // Валидация
    if (!email || !password || !name) {
      return res.status(400).json({
        success: false,
        message: 'Все поля обязательны'
      });
    }
    
    // Проверка существующего пользователя
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Пользователь с таким email уже существует'
      });
    }
    
    // Создание пользователя (пароль хешируется автоматически в модели)
    const newUser = new User({
      email: email.toLowerCase(),
      password,
      name,
      subscription: {
        type: 'free',
        isActive: false
      },
      streak: {
        current: 0,
        longest: 0
      },
      onboardingCompleted: false,
      allergies: [],
      dailyCalorieGoal: 2000
    });
    
    await newUser.save();
    
    // Создание токена
    const token = jwt.sign(
      { userId: newUser._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    
    // Удаляем пароль из ответа
    const userResponse = newUser.toObject();
    delete userResponse.password;
    
    res.status(201).json({
      success: true,
      token,
      user: userResponse
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
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Неверный email или пароль'
      });
    }
    
    // Проверка пароля (используем метод из модели)
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Неверный email или пароль'
      });
    }
    
    // Создание токена
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    
    // Удаляем пароль из ответа
    const userResponse = user.toObject();
    delete userResponse.password;
    
    res.json({
      success: true,
      token,
      user: userResponse
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
router.post('/check-version', (req, res) => {
  try {
    const { currentVersion } = req.body;
    
    if (!currentVersion) {
      return res.status(400).json({
        success: false,
        message: 'Версия приложения не указана'
      });
    }
    
    // Текущая версия серверa (можно вынести в конфиг)
    const serverVersion = '1.2.0';
    const updateDescription = 'Обновление до MongoDB Atlas и новый хостинг на Koyeb';
    
    // Сравниваем версии
    const needsUpdate = compareVersions(currentVersion, serverVersion) < 0;
    
    res.json({
      success: true,
      needsUpdate,
      currentVersion: serverVersion,
      updateDescription: updateDescription,
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
