const mongoose = require('mongoose');

const foodSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  calories: {
    type: Number,
    required: true,
    min: 0
  },
  macros: {
    protein: {
      type: Number,
      required: true,
      min: 0
    },
    fat: {
      type: Number,
      required: true,
      min: 0
    },
    carbs: {
      type: Number,
      required: true,
      min: 0
    }
  },
  image: {
    data: Buffer,
    contentType: String,
    filename: String,
    compressedSize: Number // размер сжатого изображения в байтах
  },
  meal: {
    type: String,
    enum: ['breakfast', 'lunch', 'dinner', 'snack'],
    required: true
  },
  date: {
    type: Date,
    required: true,
    default: Date.now
  },
  portion: {
    size: {
      type: Number,
      default: 1,
      min: 0.1
    },
    unit: {
      type: String,
      default: 'порция',
      trim: true
    }
  },
  tags: [{
    type: String,
    trim: true
  }],
  aiConfidence: {
    type: Number,
    min: 0,
    max: 1,
    default: 0.8
  },
  isManuallyEdited: {
    type: Boolean,
    default: false
  },
  notes: {
    type: String,
    trim: true,
    maxlength: 500
  }
}, {
  timestamps: true
});

// Составные индексы для быстрых запросов
foodSchema.index({ userId: 1, date: -1 });
foodSchema.index({ userId: 1, meal: 1, date: -1 });
foodSchema.index({ userId: 1, createdAt: -1 });

// Виртуальное поле для расчета общей энергетической ценности с учетом порции
foodSchema.virtual('totalCalories').get(function() {
  return Math.round(this.calories * this.portion.size);
});

foodSchema.virtual('totalMacros').get(function() {
  return {
    protein: Math.round(this.macros.protein * this.portion.size),
    fat: Math.round(this.macros.fat * this.portion.size),
    carbs: Math.round(this.macros.carbs * this.portion.size)
  };
});

// Статический метод для получения статистики пользователя за период
foodSchema.statics.getUserStats = async function(userId, startDate, endDate) {
  const stats = await this.aggregate([
    {
      $match: {
        userId: new mongoose.Types.ObjectId(userId),
        date: {
          $gte: new Date(startDate),
          $lte: new Date(endDate)
        }
      }
    },
    {
      $group: {
        _id: null,
        totalCalories: { 
          $sum: { $multiply: ['$calories', '$portion.size'] }
        },
        totalProtein: { 
          $sum: { $multiply: ['$macros.protein', '$portion.size'] }
        },
        totalFat: { 
          $sum: { $multiply: ['$macros.fat', '$portion.size'] }
        },
        totalCarbs: { 
          $sum: { $multiply: ['$macros.carbs', '$portion.size'] }
        },
        totalEntries: { $sum: 1 }
      }
    }
  ]);
  
  return stats[0] || {
    totalCalories: 0,
    totalProtein: 0,
    totalFat: 0,
    totalCarbs: 0,
    totalEntries: 0
  };
};

// Статический метод для получения записей пользователя по дням
foodSchema.statics.getUserFoodsByDate = async function(userId, date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);
  
  return this.find({
    userId: new mongoose.Types.ObjectId(userId),
    date: {
      $gte: startOfDay,
      $lte: endOfDay
    }
  }).sort({ createdAt: -1 });
};

module.exports = mongoose.model('Food', foodSchema);
