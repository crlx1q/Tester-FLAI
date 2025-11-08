const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const mongoURI = `mongodb+srv://${process.env.MONGODB_USERNAME}:${process.env.MONGODB_PASSWORD}@cluster0.1lfp0sx.mongodb.net/${process.env.MONGODB_DATABASE || 'foodlens'}?retryWrites=true&w=majority&appName=Cluster0`;
    
    await mongoose.connect(mongoURI, {
      serverSelectionTimeoutMS: 10000, // 10 секунд на выбор сервера
      socketTimeoutMS: 60000, // 60 секунд на операции
      maxPoolSize: 10, // Максимум 10 соединений
      minPoolSize: 2 // Минимум 2 соединения
    });
    
    console.log('✅ MongoDB Atlas подключена успешно');
  } catch (error) {
    console.error('❌ Ошибка подключения к MongoDB:', error.message);
    throw error;
  }
};

module.exports = connectDB;