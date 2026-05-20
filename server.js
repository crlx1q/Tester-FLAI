require('dotenv').config();

// ⚠️ ВАЖНО: Устанавливаем часовой пояс ГЛОБАЛЬНО для всего приложения
// Теперь new Date() везде будет возвращать время в Asia/Almaty!
process.env.TZ = process.env.TIMEZONE || 'Asia/Almaty';

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const connectDB = require('./config/database');
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const foodRoutes = require('./routes/food');
const aiRoutes = require('./routes/ai');
const recipesRoutes = require('./routes/recipes');
const streakRoutes = require('./routes/streak');
const onboardingRoutes = require('./routes/onboarding');
const adminRoutes = require('./routes/admin');
const friendsRoutes = require('./routes/friends');
const notificationsRoutes = require('./routes/notifications');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Увеличиваем лимит для base64 изображений
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Создаем необходимые директории
const directories = ['./uploads', './data', './apk'];
directories.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Статические файлы
app.use('/uploads', express.static('uploads'));

// APK файлы с правильными заголовками
app.use('/apk', express.static('apk', {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.apk')) {
      res.set({
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': 'attachment; filename="app-release.apk"',
        'Cache-Control': 'no-cache'
      });
    }
  }
}));

app.use(express.static('public'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/food', foodRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/recipes', recipesRoutes);
app.use('/api/streak', streakRoutes);
app.use('/api/onboarding', onboardingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/friends', friendsRoutes);
app.use('/api/notifications', notificationsRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'FoodLens AI Server is running' });
});

// Admin panel route
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: err.message || 'Внутренняя ошибка сервера'
  });
});

// Запуск сервера с подключением к MongoDB
const startServer = async () => {
  try {
    // Подключаемся к локальной MongoDB
    await connectDB();
    
    // Загружаем Gemini API ключ из БД
    try {
      const Database = require('./utils/database-mongo');
      const settings = await Database.getAppSettings();
      if (settings && settings.geminiApiKey) {
        process.env.GEMINI_API_KEY = settings.geminiApiKey;
        console.log('✅ Gemini API ключ загружен из БД');
      } else {
        console.log('⚠️ Gemini API ключ не найден в БД, используется из .env');
      }
    } catch (error) {
      console.error('⚠️ Ошибка загрузки Gemini API ключа:', error.message);
    }
    
    // Проверяем и обновляем streak и подписки всех пользователей
    try {
      const StartupCheckService = require('./services/startup-check');
      await StartupCheckService.runAllChecks();
    } catch (error) {
      console.error('⚠️ Ошибка проверки данных пользователей:', error.message);
    }
    
    // Запускаем сервер только после успешного подключения к БД
    app.listen(PORT, () => {
      console.log(`🚀 FoodLens AI Server запущен на порту ${PORT}`);
      console.log(`📡 API доступен по адресу: http://localhost:${PORT}/api`);
      
      // Информация о времени и часовом поясе сервера
      const timezone = process.env.TIMEZONE || 'Asia/Almaty';
      const now = new Date();
      const gmtTime = now.toUTCString();
      const localTime = now.toLocaleString('ru-RU', { timeZone: timezone });
      
      // Вычисляем GMT offset для указанного часового пояса
      const tzDate = new Date(now.toLocaleString('en-US', { timeZone: timezone }));
      const utcDate = new Date(now.toLocaleString('en-US', { timeZone: 'UTC' }));
      const gmtOffset = (tzDate - utcDate) / (1000 * 60 * 60);
      const offsetStr = gmtOffset >= 0 ? `+${gmtOffset}` : `${gmtOffset}`;
      
      console.log(`🕐 Часовой пояс: ${timezone} (GMT${offsetStr})`);
      console.log(`🌍 GMT время: ${gmtTime}`);
      console.log(`📅 Текущая дата/время: ${localTime}`);
    });
  } catch (error) {
    console.error('❌ Не удалось запустить сервер:', error);
    process.exit(1);
  }
};

startServer();
