const User = require('../models/User');
const Food = require('../models/Food');
const Recipe = require('../models/Recipe');
const WaterIntake = require('../models/WaterIntake');
const AppSettings = require('../models/AppSettings');
const sharp = require('sharp');

class Database {
  // ==================== USER METHODS ====================
  
  static async getUsers() {
    return await User.find().select('-password');
  }
  
  static async getUserById(id) {
    return await User.findById(id);
  }
  
  static async getUserByEmail(email) {
    return await User.findOne({ email: email.toLowerCase() });
  }
  
  static async createUser(userData) {
    const user = new User(userData);
    await user.save();
    return user;
  }
  
  static async updateUser(id, updates) {
    const user = await User.findByIdAndUpdate(
      id,
      { $set: updates },
      { new: true, runValidators: true }
    );
    return user;
  }
  
  static async deleteUser(userId) {
    // Удаляем пользователя
    const user = await User.findByIdAndDelete(userId);
    if (!user) return null;
    
    // Удаляем все связанные данные
    await Food.deleteMany({ userId });
    await Recipe.deleteMany({ userId });
    await WaterIntake.deleteMany({ userId });
    
    return user;
  }
  
  static async deleteUserCompletely(userId) {
    return await this.deleteUser(userId);
  }
  
  // ==================== FOOD METHODS ====================
  
  static async getFoods(userId = null) {
    if (userId) {
      return await Food.find({ userId }).sort({ timestamp: -1 });
    }
    return await Food.find().sort({ timestamp: -1 });
  }
  
  static async getFoodsByDate(userId, date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    
    return await Food.find({
      userId,
      timestamp: {
        $gte: startOfDay,
        $lte: endOfDay
      }
    }).sort({ timestamp: -1 });
  }
  
  static async createFood(foodData) {
    // Если есть imageUrl (base64 или путь), конвертируем в Buffer
    if (foodData.imageUrl) {
      try {
        let imageBuffer;
        
        if (foodData.imageUrl.startsWith('data:image')) {
          // Base64 изображение
          const base64Data = foodData.imageUrl.split('base64,')[1] || foodData.imageUrl;
          imageBuffer = Buffer.from(base64Data, 'base64');
        } else if (foodData.imageUrl.startsWith('/uploads/')) {
          // Путь к файлу - читаем файл
          const fs = require('fs');
          const path = require('path');
          const filePath = path.join(__dirname, '..', foodData.imageUrl);
          if (fs.existsSync(filePath)) {
            imageBuffer = fs.readFileSync(filePath);
          }
        }
        
        if (imageBuffer) {
          // Сжимаем изображение для экономии места (макс 200KB)
          const compressedBuffer = await sharp(imageBuffer)
            .resize(800, 800, { fit: 'inside', withoutEnlargement: true })
            .jpeg({ quality: 70, progressive: true })
            .toBuffer();
          
          foodData.image = compressedBuffer;
          foodData.imageContentType = 'image/jpeg';
        }
      } catch (error) {
        console.error('Error processing image:', error);
      }
      
      delete foodData.imageUrl; // Удаляем старое поле
    }
    
    const food = new Food(foodData);
    await food.save();
    return food;
  }
  
  static async getFoodById(id) {
    return await Food.findById(id);
  }
  
  static async updateFood(id, updates) {
    const food = await Food.findByIdAndUpdate(
      id,
      { $set: updates },
      { new: true, runValidators: true }
    );
    return food;
  }
  
  static async deleteFood(id) {
    return await Food.findByIdAndDelete(id);
  }
  
  // ==================== FAVORITE FOODS ====================
  
  static async addFavoriteFood(userId, foodData) {
    const user = await User.findById(userId);
    if (!user) return null;
    
    const favoriteFood = {
      name: foodData.name,
      calories: foodData.calories,
      macros: foodData.macros,
      addedAt: new Date()
    };
    
    user.favoriteFoods.push(favoriteFood);
    await user.save();
    
    return favoriteFood;
  }
  
  static async getFavoriteFoods(userId) {
    const user = await User.findById(userId);
    return user?.favoriteFoods || [];
  }
  
  static async removeFavoriteFood(userId, foodId) {
    const user = await User.findById(userId);
    if (!user) return null;
    
    const foodIndex = user.favoriteFoods.findIndex(f => f._id.toString() === foodId);
    if (foodIndex === -1) return null;
    
    const removedFood = user.favoriteFoods[foodIndex];
    user.favoriteFoods.splice(foodIndex, 1);
    await user.save();
    
    return removedFood;
  }
  
  // ==================== RECIPE METHODS ====================
  
  static async getRecipes(userId = null) {
    if (userId) {
      return await Recipe.find({ userId }).sort({ createdAt: -1 });
    }
    return await Recipe.find().sort({ createdAt: -1 });
  }
  
  static async createRecipe(recipeData) {
    // Если есть imageUrl, конвертируем в Buffer
    if (recipeData.imageUrl) {
      try {
        let imageBuffer;
        
        if (recipeData.imageUrl.startsWith('data:image')) {
          const base64Data = recipeData.imageUrl.split('base64,')[1] || recipeData.imageUrl;
          imageBuffer = Buffer.from(base64Data, 'base64');
        } else if (recipeData.imageUrl.startsWith('/uploads/')) {
          const fs = require('fs');
          const path = require('path');
          const filePath = path.join(__dirname, '..', recipeData.imageUrl);
          if (fs.existsSync(filePath)) {
            imageBuffer = fs.readFileSync(filePath);
          }
        }
        
        if (imageBuffer) {
          // Сжимаем изображение
          const compressedBuffer = await sharp(imageBuffer)
            .resize(800, 800, { fit: 'inside', withoutEnlargement: true })
            .jpeg({ quality: 70, progressive: true })
            .toBuffer();
          
          recipeData.image = compressedBuffer;
          recipeData.imageContentType = 'image/jpeg';
        }
      } catch (error) {
        console.error('Error processing recipe image:', error);
      }
      
      delete recipeData.imageUrl;
    }
    
    const recipe = new Recipe(recipeData);
    await recipe.save();
    return recipe;
  }
  
  static async getRecipeById(id) {
    return await Recipe.findById(id);
  }
  
  static async updateRecipe(id, updates) {
    const recipe = await Recipe.findByIdAndUpdate(
      id,
      { $set: updates },
      { new: true, runValidators: true }
    );
    return recipe;
  }
  
  static async deleteRecipe(id) {
    return await Recipe.findByIdAndDelete(id);
  }
  
  // ==================== WATER TRACKING ====================
  
  static async getWaterIntakes(userId = null) {
    if (userId) {
      return await WaterIntake.find({ userId }).sort({ date: -1 });
    }
    return await WaterIntake.find().sort({ date: -1 });
  }
  
  static async getWaterIntakeByDate(userId, date) {
    const targetDate = new Date(date);
    const dateStr = targetDate.toISOString().split('T')[0];
    
    return await WaterIntake.findOne({ userId, date: dateStr });
  }
  
  static async saveWaterIntake(userId, date, amount) {
    const targetDate = new Date(date);
    const dateStr = targetDate.toISOString().split('T')[0];
    
    // Используем upsert для создания или обновления
    const waterIntake = await WaterIntake.findOneAndUpdate(
      { userId, date: dateStr },
      { $set: { amount } },
      { new: true, upsert: true, runValidators: true }
    );
    
    return waterIntake;
  }
  
  // ==================== SUBSCRIPTION & USAGE ====================
  
  static async getUserUsage(userId) {
    const user = await User.findById(userId);
    if (!user) return null;
    
    const today = new Date().toISOString().split('T')[0];
    
    if (!user.usage || user.usage.date !== today) {
      return {
        date: today,
        photosCount: 0,
        messagesCount: 0,
        recipesCount: 0
      };
    }
    
    return user.usage;
  }
  
  static async incrementUserUsage(userId, field) {
    const user = await User.findById(userId);
    if (!user) return null;
    
    const today = new Date().toISOString().split('T')[0];
    
    // Сбрасываем счетчики если новый день
    if (!user.usage || user.usage.date !== today) {
      user.usage = {
        date: today,
        photosCount: 0,
        messagesCount: 0,
        recipesCount: 0
      };
    }
    
    // Увеличиваем нужный счетчик
    if (field === 'photos') {
      user.usage.photosCount = (user.usage.photosCount || 0) + 1;
    } else if (field === 'messages') {
      user.usage.messagesCount = (user.usage.messagesCount || 0) + 1;
    } else if (field === 'recipes') {
      user.usage.recipesCount = (user.usage.recipesCount || 0) + 1;
    }
    
    await user.save();
    return user.usage;
  }
  
  static async updateUserSubscription(userId, subscriptionType, expiresAt = null) {
    const user = await User.findByIdAndUpdate(
      userId,
      {
        $set: {
          subscriptionType,
          subscriptionExpiresAt: expiresAt,
          isPro: subscriptionType === 'pro'
        }
      },
      { new: true }
    );
    
    return user;
  }
  
  // ==================== ADMIN METHODS ====================
  
  static async getAllUsersForAdmin() {
    return await User.find().select('-password');
  }
  
  // ==================== APP SETTINGS ====================
  
  static async getAppSettings() {
    let settings = await AppSettings.findOne();
    
    if (!settings) {
      settings = new AppSettings({
        registrationEnabled: true,
        currentVersion: '1.2.0',
        updateDescription: '',
        hasUpdate: false
      });
      await settings.save();
    }
    
    return settings;
  }
  
  static async updateAppSettings(updates) {
    let settings = await AppSettings.findOne();
    
    if (!settings) {
      settings = new AppSettings(updates);
    } else {
      Object.assign(settings, updates);
    }
    
    await settings.save();
    return settings;
  }
}

module.exports = Database;
