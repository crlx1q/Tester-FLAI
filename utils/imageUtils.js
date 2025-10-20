const sharp = require('sharp');
const fs = require('fs');

/**
 * Сжимает изображение и конвертирует в формат для хранения в MongoDB
 * @param {string} imagePath - путь к изображению
 * @param {number} maxWidth - максимальная ширина (по умолчанию 800px)
 * @param {number} quality - качество JPEG (по умолчанию 80)
 * @returns {Object} - объект с данными для сохранения в MongoDB
 */
async function compressImageForMongoDB(imagePath, maxWidth = 800, quality = 80) {
  try {
    // Читаем исходное изображение
    const inputBuffer = fs.readFileSync(imagePath);
    const originalSize = inputBuffer.length;
    
    // Получаем информацию об изображении
    const metadata = await sharp(inputBuffer).metadata();
    
    // Определяем нужно ли изменять размер
    const needsResize = metadata.width > maxWidth;
    
    // Обрабатываем изображение
    let sharpInstance = sharp(inputBuffer);
    
    if (needsResize) {
      sharpInstance = sharpInstance.resize(maxWidth, null, {
        withoutEnlargement: true,
        fit: 'inside'
      });
    }
    
    // Конвертируем в JPEG и сжимаем
    const compressedBuffer = await sharpInstance
      .jpeg({ 
        quality: quality,
        progressive: true,
        mozjpeg: true // лучшее сжатие
      })
      .toBuffer();
    
    const compressedSize = compressedBuffer.length;
    const filename = `compressed_${Date.now()}.jpg`;
    
    console.log(`📸 Изображение сжато: ${originalSize} → ${compressedSize} байт (${Math.round((1 - compressedSize/originalSize) * 100)}% экономии)`);
    
    return {
      data: compressedBuffer,
      contentType: 'image/jpeg',
      filename: filename,
      compressedSize: compressedSize
    };
  } catch (error) {
    console.error('❌ Ошибка сжатия изображения:', error);
    throw new Error('Не удалось обработать изображение');
  }
}

/**
 * Сжимает изображение для профиля пользователя (меньший размер)
 * @param {string} imagePath - путь к изображению
 * @returns {Object} - объект с данными для сохранения в MongoDB
 */
async function compressProfileImage(imagePath) {
  return compressImageForMongoDB(imagePath, 400, 75); // 400px, качество 75%
}

/**
 * Сжимает изображение еды
 * @param {string} imagePath - путь к изображению
 * @returns {Object} - объект с данными для сохранения в MongoDB
 */
async function compressFoodImage(imagePath) {
  return compressImageForMongoDB(imagePath, 800, 80); // 800px, качество 80%
}

/**
 * Сжимает изображение для рецепта
 * @param {string} imagePath - путь к изображению
 * @returns {Object} - объект с данными для сохранения в MongoDB
 */
async function compressRecipeImage(imagePath) {
  return compressImageForMongoDB(imagePath, 600, 78); // 600px, качество 78%
}

/**
 * Конвертирует Buffer в base64 для отправки клиенту
 * @param {Buffer} buffer - буфер изображения
 * @param {string} contentType - MIME тип изображения
 * @returns {string} - base64 строка
 */
function bufferToBase64(buffer, contentType) {
  if (!buffer || !contentType) return null;
  return `data:${contentType};base64,${buffer.toString('base64')}`;
}

/**
 * Проверяет, является ли файл изображением
 * @param {string} filename - имя файла
 * @returns {boolean}
 */
function isImageFile(filename) {
  const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
  const ext = filename.toLowerCase().substring(filename.lastIndexOf('.'));
  return imageExtensions.includes(ext);
}

/**
 * Получает размер изображения в человекочитаемом формате
 * @param {number} bytes - размер в байтах
 * @returns {string}
 */
function formatImageSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Создает превью изображения (очень маленький размер для списков)
 * @param {string} imagePath - путь к изображению
 * @returns {Object} - объект с данными превью
 */
async function createImageThumbnail(imagePath) {
  return compressImageForMongoDB(imagePath, 150, 60); // 150px, качество 60%
}

module.exports = {
  compressImageForMongoDB,
  compressProfileImage,
  compressFoodImage,
  compressRecipeImage,
  bufferToBase64,
  isImageFile,
  formatImageSize,
  createImageThumbnail
};
