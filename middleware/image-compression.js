const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

/**
 * Middleware для сжатия изображений
 * - Free пользователи: максимум 25MB до сжатия
 * - Pro пользователи: без ограничений по размеру
 * - Все изображения сжимаются для оптимизации
 */

// Проверка размера файла для free пользователей
const checkFileSizeLimit = (req, res, next) => {
  const Database = require('../utils/database');
  
  // Проверяем только если есть файл
  if (!req.file) {
    return next();
  }
  
  // Получаем пользователя
  const user = Database.getUserById(req.userId);
  
  if (!user) {
    return res.status(401).json({
      success: false,
      message: 'Пользователь не найден'
    });
  }
  
  // Проверяем подписку
  const isPro = user.subscriptionType === 'pro';
  
  // Для free пользователей проверяем лимит 25MB
  if (!isPro) {
    const maxSize = 25 * 1024 * 1024; // 25MB в байтах
    const fileSize = req.file.size;
    
    if (fileSize > maxSize) {
      // Удаляем загруженный файл
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
      
      return res.status(413).json({
        success: false,
        message: 'Размер файла превышает 25MB. Обновитесь до Pro для загрузки больших файлов.',
        limit: '25MB',
        fileSize: `${(fileSize / (1024 * 1024)).toFixed(2)}MB`
      });
    }
  }
  
  next();
};

// Сжатие изображения
const compressImage = async (req, res, next) => {
  try {
    // Если файла нет, пропускаем
    if (!req.file) {
      return next();
    }
    
    const inputPath = req.file.path;
    const outputPath = inputPath.replace(/\.(jpg|jpeg|png|gif|webp|heic|heif)$/i, '-compressed.jpg');
    
    console.log(`🖼️ Сжатие изображения: ${req.file.filename}`);
    console.log(`📦 Исходный размер: ${(req.file.size / 1024).toFixed(2)} KB`);
    
    // Сжимаем изображение с помощью sharp с сохранением ориентации
    await sharp(inputPath)
      .rotate() // Автоматически поворачивает на основе EXIF данных
      .resize(1920, 1920, { // Максимальные размеры
        fit: 'inside',
        withoutEnlargement: true
      })
      .jpeg({
        quality: 85, // Качество 85% - хороший баланс между качеством и размером
        progressive: true,
        mozjpeg: true
      })
      .toFile(outputPath);
    
    // Получаем размер сжатого файла
    const compressedStats = fs.statSync(outputPath);
    const compressionRatio = ((1 - compressedStats.size / req.file.size) * 100).toFixed(2);
    
    console.log(`📦 Сжатый размер: ${(compressedStats.size / 1024).toFixed(2)} KB`);
    console.log(`✅ Сжатие: ${compressionRatio}%`);
    
    // Удаляем оригинальный файл (с повторными попытками для Windows)
    const deleteOriginalFile = async (filePath, retries = 3) => {
      for (let i = 0; i < retries; i++) {
        try {
          if (fs.existsSync(filePath)) {
            // Используем промисифицированную версию для лучшей обработки
            await fs.promises.unlink(filePath);
            return true;
          }
          return false;
        } catch (err) {
          if (err.code === 'EPERM' && i < retries - 1) {
            // Ждем немного перед повторной попыткой (Windows может держать файл)
            await new Promise(resolve => setTimeout(resolve, 100));
            continue;
          }
          // Если не удалось удалить после всех попыток, просто логируем
          console.warn(`⚠️ Не удалось удалить оригинальный файл: ${err.message}`);
          return false;
        }
      }
    };
    
    // Удаляем оригинальный файл и переименовываем сжатый
    await deleteOriginalFile(inputPath);
    
    // Переименовываем сжатый файл в оригинальное имя
    try {
      await fs.promises.rename(outputPath, inputPath);
      
      // Обновляем информацию о файле в req.file (путь остается прежним)
      req.file.size = compressedStats.size;
    } catch (renameError) {
      console.warn(`⚠️ Не удалось переименовать файл, используем сжатую версию: ${renameError.message}`);
      // Если переименование не удалось, используем сжатый файл
      req.file.path = outputPath;
      req.file.filename = path.basename(outputPath);
      req.file.size = compressedStats.size;
    }
    
    next();
  } catch (error) {
    console.error('Ошибка сжатия изображения:', error);
    
    // В случае ошибки пытаемся удалить файлы
    const cleanupFiles = async () => {
      const filesToClean = [req.file?.path];
      const outputPath = req.file?.path?.replace(/\.(jpg|jpeg|png|gif|webp|heic|heif)$/i, '-compressed.jpg');
      if (outputPath) filesToClean.push(outputPath);
      
      for (const file of filesToClean) {
        if (file && fs.existsSync(file)) {
          try {
            await fs.promises.unlink(file);
          } catch (err) {
            console.warn(`⚠️ Не удалось удалить файл при очистке: ${err.message}`);
          }
        }
      }
    };
    
    await cleanupFiles();
    
    res.status(500).json({
      success: false,
      message: 'Ошибка обработки изображения'
    });
  }
};

// Сжатие base64 изображения
const compressBase64Image = async (base64Data) => {
  try {
    const buffer = Buffer.from(base64Data, 'base64');
    
    console.log(`🖼️ Сжатие base64 изображения`);
    console.log(`📦 Исходный размер: ${(buffer.length / 1024).toFixed(2)} KB`);
    
    const compressedBuffer = await sharp(buffer)
      .rotate() // Автоматически поворачивает на основе EXIF данных
      .resize(1920, 1920, {
        fit: 'inside',
        withoutEnlargement: true
      })
      .jpeg({
        quality: 85,
        progressive: true,
        mozjpeg: true
      })
      .toBuffer();
    
    const compressionRatio = ((1 - compressedBuffer.length / buffer.length) * 100).toFixed(2);
    
    console.log(`📦 Сжатый размер: ${(compressedBuffer.length / 1024).toFixed(2)} KB`);
    console.log(`✅ Сжатие: ${compressionRatio}%`);
    
    return compressedBuffer;
  } catch (error) {
    console.error('Ошибка сжатия base64 изображения:', error);
    throw error;
  }
};

// Проверка размера base64 для free пользователей
const checkBase64SizeLimit = (userId, base64Data) => {
  const Database = require('../utils/database');
  const user = Database.getUserById(userId);
  
  if (!user) {
    throw new Error('Пользователь не найден');
  }
  
  const isPro = user.subscriptionType === 'pro';
  
  if (!isPro) {
    const buffer = Buffer.from(base64Data, 'base64');
    const maxSize = 25 * 1024 * 1024; // 25MB
    
    if (buffer.length > maxSize) {
      const error = new Error('Размер файла превышает 25MB. Обновитесь до Pro для загрузки больших файлов.');
      error.statusCode = 413;
      error.fileSize = `${(buffer.length / (1024 * 1024)).toFixed(2)}MB`;
      throw error;
    }
  }
};

module.exports = {
  checkFileSizeLimit,
  compressImage,
  compressBase64Image,
  checkBase64SizeLimit
};
