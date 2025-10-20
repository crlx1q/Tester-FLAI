const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  password: {
    type: String,
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  age: {
    type: Number,
    min: 1,
    max: 120
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other']
  },
  height: {
    type: Number,
    min: 50,
    max: 300
  },
  weight: {
    type: Number,
    min: 20,
    max: 500
  },
  activityLevel: {
    type: String,
    enum: ['sedentary', 'light', 'moderate', 'active', 'very_active'],
    default: 'moderate'
  },
  goal: {
    type: String,
    enum: ['lose_weight', 'maintain_weight', 'gain_weight'],
    default: 'maintain_weight'
  },
  dailyCalorieGoal: {
    type: Number,
    default: 2000
  },
  profileImage: {
    data: Buffer,
    contentType: String,
    filename: String
  },
  onboardingCompleted: {
    type: Boolean,
    default: false
  },
  dietPlan: {
    type: String,
    enum: ['regular', 'vegetarian', 'vegan', 'keto', 'paleo', 'mediterranean'],
    default: 'regular'
  },
  allergies: [{
    type: String,
    trim: true
  }],
  preferences: {
    language: {
      type: String,
      default: 'ru'
    },
    notifications: {
      type: Boolean,
      default: true
    },
    darkMode: {
      type: Boolean,
      default: false
    }
  },
  streak: {
    current: {
      type: Number,
      default: 0
    },
    longest: {
      type: Number,
      default: 0
    },
    lastLogDate: {
      type: Date
    }
  },
  subscription: {
    type: {
      type: String,
      enum: ['free', 'premium'],
      default: 'free'
    },
    expiresAt: Date,
    isActive: {
      type: Boolean,
      default: false
    }
  }
}, {
  timestamps: true
});

// Индексы для быстрого поиска
userSchema.index({ email: 1 });
userSchema.index({ createdAt: -1 });

// Хеширование пароля перед сохранением
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Метод для проверки пароля
userSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Виртуальное поле для полного имени
userSchema.virtual('fullName').get(function() {
  return this.name;
});

// При удалении пользователя - удаляем все связанные данные
userSchema.pre('deleteOne', { document: true, query: false }, async function(next) {
  try {
    const Food = mongoose.model('Food');
    const Recipe = mongoose.model('Recipe');
    
    // Удаляем все записи о еде пользователя
    await Food.deleteMany({ userId: this._id });
    
    // Удаляем все рецепты пользователя
    await Recipe.deleteMany({ userId: this._id });
    
    console.log(`🗑️ Удалены все данные пользователя: ${this.email}`);
    next();
  } catch (error) {
    next(error);
  }
});

module.exports = mongoose.model('User', userSchema);
