const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, '../data/database.json');

class Database {
  static read() {
    const data = fs.readFileSync(dbPath, 'utf8');
    return JSON.parse(data);
  }
  
  static write(data) {
    fs.writeFileSync(dbPath, JSON.stringify(data, null, 2));
  }
  
  static getUsers() {
    const db = this.read();
    return db.users;
  }
  
  static getUserById(id) {
    const users = this.getUsers();
    return users.find(u => u._id === id);
  }
  
  static getUserByEmail(email) {
    const users = this.getUsers();
    return users.find(u => u.email === email);
  }
  
  static createUser(userData) {
    const db = this.read();
    const newId = (db.lastUserId + 1).toString();
    const newUser = {
      _id: newId,
      ...userData,
      createdAt: new Date().toISOString()
    };
    db.users.push(newUser);
    db.lastUserId++;
    this.write(db);
    return newUser;
  }
  
  static updateUser(id, updates) {
    const db = this.read();
    const userIndex = db.users.findIndex(u => u._id === id);
    if (userIndex === -1) return null;
    
    db.users[userIndex] = {
      ...db.users[userIndex],
      ...updates,
      updatedAt: new Date().toISOString()
    };
    this.write(db);
    return db.users[userIndex];
  }
  
  static getFoods(userId = null) {
    const db = this.read();
    if (userId) {
      return db.foods.filter(f => f.userId === userId);
    }
    return db.foods;
  }
  
  static getFoodsByDate(userId, date) {
    const foods = this.getFoods(userId);
    
    // Работаем с локальными датами для корректного сравнения
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    
    return foods.filter(f => {
      const foodDate = new Date(f.timestamp);
      return foodDate >= startOfDay && foodDate <= endOfDay;
    });
  }
  
  static createFood(foodData) {
    const db = this.read();
    const newId = (db.lastFoodId + 1).toString();
    const timestamp = new Date().toISOString();
    const newFood = {
      _id: newId,
      ...foodData,
      timestamp: timestamp
    };
    db.foods.push(newFood);
    db.lastFoodId++;
    this.write(db);
    return newFood;
  }
  
  static getFoodById(id) {
    const db = this.read();
    return db.foods.find(f => f._id === id);
  }
  
  static updateFood(id, updates) {
    const db = this.read();
    const foodIndex = db.foods.findIndex(f => f._id === id);
    if (foodIndex === -1) return null;
    
    // Обновляем только переданные поля
    db.foods[foodIndex] = {
      ...db.foods[foodIndex],
      ...updates,
      _id: id // Сохраняем ID
    };
    
    this.write(db);
    return db.foods[foodIndex];
  }
  
  static deleteFood(id) {
    const db = this.read();
    const foodIndex = db.foods.findIndex(f => f._id === id);
    if (foodIndex === -1) return null;
    
    const deletedFood = db.foods[foodIndex];
    db.foods.splice(foodIndex, 1);
    this.write(db);
    return deletedFood;
  }
  
  static addFavoriteFood(userId, foodData) {
    const db = this.read();
    const user = db.users.find(u => u._id === userId);
    if (!user) return null;
    
    if (!user.favoriteFoods) {
      user.favoriteFoods = [];
    }
    
    // Создаем избранное блюдо без фото
    const favoriteFood = {
      _id: Date.now().toString(),
      name: foodData.name,
      calories: foodData.calories,
      macros: foodData.macros,
      addedAt: new Date().toISOString()
    };
    
    user.favoriteFoods.push(favoriteFood);
    this.write(db);
    return favoriteFood;
  }
  
  static getFavoriteFoods(userId) {
    const user = this.getUserById(userId);
    return user?.favoriteFoods || [];
  }
  
  static removeFavoriteFood(userId, foodId) {
    const db = this.read();
    const user = db.users.find(u => u._id === userId);
    if (!user || !user.favoriteFoods) return null;
    
    const foodIndex = user.favoriteFoods.findIndex(f => f._id === foodId);
    if (foodIndex === -1) return null;
    
    const removedFood = user.favoriteFoods[foodIndex];
    user.favoriteFoods.splice(foodIndex, 1);
    this.write(db);
    return removedFood;
  }
  
  static getRecipes(userId = null) {
    const db = this.read();
    if (!db.recipes) {
      db.recipes = [];
      this.write(db);
    }
    if (userId) {
      return db.recipes.filter(r => r.userId === userId);
    }
    return db.recipes;
  }
  
  static createRecipe(recipeData) {
    const db = this.read();
    if (!db.recipes) {
      db.recipes = [];
    }
    if (!db.lastRecipeId) {
      db.lastRecipeId = 0;
    }
    
    const newId = (db.lastRecipeId + 1).toString();
    const newRecipe = {
      _id: newId,
      ...recipeData,
      createdAt: new Date().toISOString()
    };
    db.recipes.push(newRecipe);
    db.lastRecipeId++;
    this.write(db);
    return newRecipe;
  }
  
  static getRecipeById(id) {
    const db = this.read();
    if (!db.recipes) return null;
    return db.recipes.find(r => r._id === id);
  }
  
  static updateRecipe(id, updates) {
    const db = this.read();
    if (!db.recipes) return null;
    
    const recipeIndex = db.recipes.findIndex(r => r._id === id);
    if (recipeIndex === -1) return null;
    
    db.recipes[recipeIndex] = {
      ...db.recipes[recipeIndex],
      ...updates,
      _id: id,
      updatedAt: new Date().toISOString()
    };
    
    this.write(db);
    return db.recipes[recipeIndex];
  }
  
  static deleteRecipe(id) {
    const db = this.read();
    if (!db.recipes) return null;
    
    const recipeIndex = db.recipes.findIndex(r => r._id === id);
    if (recipeIndex === -1) return null;
    
    const deletedRecipe = db.recipes[recipeIndex];
    db.recipes.splice(recipeIndex, 1);
    this.write(db);
    return deletedRecipe;
  }
  
  // Water tracking methods
  static getWaterIntakes(userId = null) {
    const db = this.read();
    if (!db.waterIntakes) {
      db.waterIntakes = [];
      this.write(db);
    }
    if (userId) {
      return db.waterIntakes.filter(w => w.userId === userId);
    }
    return db.waterIntakes;
  }
  
  static getWaterIntakeByDate(userId, date) {
    const waterIntakes = this.getWaterIntakes(userId);
    
    // Нормализуем дату для сравнения (только год-месяц-день)
    const targetDate = new Date(date);
    const dateStr = targetDate.toISOString().split('T')[0];
    
    return waterIntakes.find(w => {
      const wDate = new Date(w.date);
      const wDateStr = wDate.toISOString().split('T')[0];
      return wDateStr === dateStr;
    });
  }
  
  static saveWaterIntake(userId, date, amount) {
    const db = this.read();
    if (!db.waterIntakes) {
      db.waterIntakes = [];
    }
    if (!db.lastWaterIntakeId) {
      db.lastWaterIntakeId = 0;
    }
    
    // Нормализуем дату
    const targetDate = new Date(date);
    const dateStr = targetDate.toISOString().split('T')[0];
    
    // Проверяем, есть ли уже запись для этой даты
    const existingIndex = db.waterIntakes.findIndex(w => {
      const wDate = new Date(w.date);
      const wDateStr = wDate.toISOString().split('T')[0];
      return w.userId === userId && wDateStr === dateStr;
    });
    
    if (existingIndex !== -1) {
      // Обновляем существующую запись
      db.waterIntakes[existingIndex].amount = amount;
      db.waterIntakes[existingIndex].updatedAt = new Date().toISOString();
      this.write(db);
      return db.waterIntakes[existingIndex];
    } else {
      // Создаем новую запись
      const newId = (db.lastWaterIntakeId + 1).toString();
      const newWaterIntake = {
        _id: newId,
        userId: userId,
        date: dateStr,
        amount: amount,
        createdAt: new Date().toISOString()
      };
      db.waterIntakes.push(newWaterIntake);
      db.lastWaterIntakeId++;
      this.write(db);
      return newWaterIntake;
    }
  }
  
  // Subscription and usage tracking methods
  static getUserUsage(userId) {
    const user = this.getUserById(userId);
    if (!user) return null;
    
    const today = new Date().toISOString().split('T')[0];
    
    // Инициализируем usage если нет
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
  
  static incrementUserUsage(userId, field) {
    const db = this.read();
    const userIndex = db.users.findIndex(u => u._id === userId);
    if (userIndex === -1) return null;
    
    const user = db.users[userIndex];
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
    
    this.write(db);
    return user.usage;
  }
  
  static updateUserSubscription(userId, subscriptionType, expiresAt = null) {
    const db = this.read();
    const userIndex = db.users.findIndex(u => u._id === userId);
    if (userIndex === -1) return null;
    
    db.users[userIndex].subscriptionType = subscriptionType;
    db.users[userIndex].subscriptionExpiresAt = expiresAt;
    db.users[userIndex].isPro = subscriptionType === 'pro';
    db.users[userIndex].updatedAt = new Date().toISOString();
    
    this.write(db);
    return db.users[userIndex];
  }
  
  static getAllUsersForAdmin() {
    const users = this.getUsers();
    return users.map(user => {
      const { password, ...userWithoutPassword } = user;
      return userWithoutPassword;
    });
  }
  
  // Полное удаление пользователя со всеми данными
  static deleteUserCompletely(userId) {
    const db = this.read();
    
    // Удаляем пользователя
    const userIndex = db.users.findIndex(u => u._id === userId);
    if (userIndex === -1) return null;
    
    const deletedUser = db.users[userIndex];
    
    // Удаляем аватарку пользователя
    if (deletedUser.avatar && deletedUser.avatar.startsWith('/uploads/')) {
      const avatarPath = path.join(__dirname, '..', deletedUser.avatar);
      if (fs.existsSync(avatarPath)) {
        try {
          fs.unlinkSync(avatarPath);
          console.log(`Deleted avatar: ${avatarPath}`);
        } catch (err) {
          console.error(`Error deleting avatar: ${err}`);
        }
      }
    }
    
    // Удаляем фотографии блюд пользователя
    if (db.foods) {
      const userFoods = db.foods.filter(f => f.userId === userId);
      userFoods.forEach(food => {
        if (food.imageUrl && food.imageUrl.startsWith('/uploads/')) {
          const filePath = path.join(__dirname, '..', food.imageUrl);
          if (fs.existsSync(filePath)) {
            try {
              fs.unlinkSync(filePath);
              console.log(`Deleted food image: ${filePath}`);
            } catch (err) {
              console.error(`Error deleting food image: ${err}`);
            }
          }
        }
      });
      db.foods = db.foods.filter(f => f.userId !== userId);
    }
    
    // Удаляем фотографии рецептов пользователя
    if (db.recipes) {
      const userRecipes = db.recipes.filter(r => r.userId === userId);
      userRecipes.forEach(recipe => {
        if (recipe.imageUrl && recipe.imageUrl.startsWith('/uploads/')) {
          const filePath = path.join(__dirname, '..', recipe.imageUrl);
          if (fs.existsSync(filePath)) {
            try {
              fs.unlinkSync(filePath);
              console.log(`Deleted recipe image: ${filePath}`);
            } catch (err) {
              console.error(`Error deleting recipe image: ${err}`);
            }
          }
        }
      });
      db.recipes = db.recipes.filter(r => r.userId !== userId);
    }
    
    // Удаляем пользователя из массива
    db.users.splice(userIndex, 1);
    
    // Удаляем записи воды
    if (db.waterIntakes) {
      db.waterIntakes = db.waterIntakes.filter(w => w.userId !== userId);
    }
    
    // Удаляем streak данные (если есть)
    if (db.streaks) {
      db.streaks = db.streaks.filter(s => s.userId !== userId);
    }
    
    this.write(db);
    return deletedUser;
  }
  
  // Алиас для удаления пользователя
  static deleteUser(userId) {
    return this.deleteUserCompletely(userId);
  }
  
  // App Settings methods
  static getAppSettings() {
    const db = this.read();
    if (!db.appSettings) {
      db.appSettings = {
        registrationEnabled: true,
        currentVersion: '1.2.0',
        updateDescription: '',
        hasUpdate: false
      };
      this.write(db);
    }
    return db.appSettings;
  }
  
  static updateAppSettings(settings) {
    const db = this.read();
    if (!db.appSettings) {
      db.appSettings = {};
    }
    db.appSettings = {
      ...db.appSettings,
      ...settings,
      updatedAt: new Date().toISOString()
    };
    this.write(db);
    return db.appSettings;
  }
}

module.exports = Database;
