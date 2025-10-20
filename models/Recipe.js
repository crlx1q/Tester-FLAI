const mongoose = require('mongoose');

const recipeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  description: {
    type: String,
    trim: true,
    maxlength: 1000
  },
  ingredients: [{
    name: {
      type: String,
      required: true,
      trim: true
    },
    amount: {
      type: String,
      required: true,
      trim: true
    },
    unit: {
      type: String,
      trim: true,
      default: ''
    }
  }],
  instructions: [{
    step: {
      type: Number,
      required: true
    },
    description: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500
    }
  }],
  nutrition: {
    calories: {
      type: Number,
      min: 0
    },
    protein: {
      type: Number,
      min: 0
    },
    fat: {
      type: Number,
      min: 0
    },
    carbs: {
      type: Number,
      min: 0
    },
    servings: {
      type: Number,
      default: 1,
      min: 1
    }
  },
  images: [{
    data: Buffer,
    contentType: String,
    filename: String,
    compressedSize: Number
  }],
  cookingTime: {
    prep: {
      type: Number, // в минутах
      min: 0
    },
    cook: {
      type: Number, // в минутах  
      min: 0
    },
    total: {
      type: Number, // в минутах
      min: 0
    }
  },
  difficulty: {
    type: String,
    enum: ['easy', 'medium', 'hard'],
    default: 'medium'
  },
  category: {
    type: String,
    enum: ['breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'appetizer', 'soup', 'salad'],
    required: true
  },
  cuisine: {
    type: String,
    trim: true,
    default: 'Международная'
  },
  tags: [{
    type: String,
    trim: true
  }],
  isPublic: {
    type: Boolean,
    default: false
  },
  isFavorite: {
    type: Boolean,
    default: false
  },
  rating: {
    value: {
      type: Number,
      min: 1,
      max: 5
    },
    notes: {
      type: String,
      trim: true,
      maxlength: 300
    }
  },
  source: {
    type: String,
    enum: ['user_created', 'ai_generated', 'imported'],
    default: 'user_created'
  },
  aiPrompt: {
    type: String,
    trim: true // сохраняем промпт, если рецепт был создан через AI
  }
}, {
  timestamps: true
});

// Индексы
recipeSchema.index({ userId: 1, createdAt: -1 });
recipeSchema.index({ userId: 1, category: 1 });
recipeSchema.index({ userId: 1, isFavorite: 1 });
recipeSchema.index({ title: 'text', description: 'text' }); // для поиска по тексту

// Виртуальное поле для общего времени приготовления
recipeSchema.virtual('totalTime').get(function() {
  if (this.cookingTime && this.cookingTime.total) {
    return this.cookingTime.total;
  }
  if (this.cookingTime && this.cookingTime.prep && this.cookingTime.cook) {
    return this.cookingTime.prep + this.cookingTime.cook;
  }
  return 0;
});

// Виртуальное поле для калорий на порцию
recipeSchema.virtual('caloriesPerServing').get(function() {
  if (this.nutrition && this.nutrition.calories && this.nutrition.servings) {
    return Math.round(this.nutrition.calories / this.nutrition.servings);
  }
  return 0;
});

// Статический метод для поиска рецептов пользователя
recipeSchema.statics.searchUserRecipes = async function(userId, query, category, limit = 20) {
  const searchQuery = { userId: new mongoose.Types.ObjectId(userId) };
  
  if (category && category !== 'all') {
    searchQuery.category = category;
  }
  
  if (query && query.trim()) {
    searchQuery.$text = { $search: query.trim() };
  }
  
  return this.find(searchQuery)
    .sort({ createdAt: -1 })
    .limit(limit);
};

// Статический метод для получения избранных рецептов
recipeSchema.statics.getFavoriteRecipes = async function(userId) {
  return this.find({
    userId: new mongoose.Types.ObjectId(userId),
    isFavorite: true
  }).sort({ createdAt: -1 });
};

// Pre-save middleware для расчета общего времени
recipeSchema.pre('save', function(next) {
  if (this.cookingTime && this.cookingTime.prep && this.cookingTime.cook) {
    this.cookingTime.total = this.cookingTime.prep + this.cookingTime.cook;
  }
  next();
});

module.exports = mongoose.model('Recipe', recipeSchema);
