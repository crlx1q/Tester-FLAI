const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const mongoURI = `mongodb+srv://${process.env.MONGODB_USERNAME}:${process.env.MONGODB_PASSWORD}@cluster0.1lfp0sx.mongodb.net/${process.env.MONGODB_DATABASE || 'foodlens'}?retryWrites=true&w=majority&appName=Cluster0`;
    
    await mongoose.connect(mongoURI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log('✅ MongoDB Atlas подключена успешно');
  } catch (error) {
    console.error('❌ Ошибка подключения к MongoDB:', error.message);
    process.exit(1);
  }
};

module.exports = connectDB;
