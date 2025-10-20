require('dotenv').config();
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

const app = express();
const PORT = process.env.PORT || 8000;

// Подключаемся к MongoDB Atlas
connectDB();

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

// MongoDB Atlas теперь используется вместо JSON файлов
console.log('📦 Используется MongoDB Atlas для хранения данных');

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/food', foodRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/recipes', recipesRoutes);
app.use('/api/streak', streakRoutes);
app.use('/api/onboarding', onboardingRoutes);
app.use('/api/admin', adminRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'FoodLens AI Server is running' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: err.message || 'Внутренняя ошибка сервера'
  });
});

app.listen(PORT, () => {
  console.log(`🚀 FoodLens AI Server запущен на порту ${PORT}`);
  console.log(`📡 API доступен по адресу: http://localhost:${PORT}/api`);
});
