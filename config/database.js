const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log(`🍃 MongoDB Atlas подключен: ${conn.connection.host}`);
    console.log(`📊 База данных: ${conn.connection.name}`);
  } catch (error) {
    console.error('❌ Ошибка подключения к MongoDB Atlas:', error);
    process.exit(1);
  }
};

module.exports = connectDB;
