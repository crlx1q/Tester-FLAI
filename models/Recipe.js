const mongoose = require('mongoose');

const recipeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true
  },
  image: {
    type: Buffer, // Храним изображение как Buffer
    default: null
  },
  imageContentType: {
    type: String,
    default: null
  },
  calories: {
    type: Number,
    default: 0
  },
  macros: {
    protein: { type: Number, default: 0 },
    fat: { type: Number, default: 0 },
    carbs: { type: Number, default: 0 }
  },
  protein: { type: Number, default: 0 },
  fat: { type: Number, default: 0 },
  carbs: { type: Number, default: 0 },
  prepTime: {
    type: Number,
    default: 30
  },
  difficulty: {
    type: String,
    default: 'Средне'
  },
  servings: {
    type: Number,
    default: 1
  },
  cookTime: {
    type: String,
    default: '00:30'
  },
  goal: {
    type: String,
    default: null
  },
  allergies: [{
    type: String
  }],
  ingredients: [{
    name: String,
    amount: String,
    unit: String,
    calories: Number
  }],
  instructions: [{
    type: String
  }],
  isFavorite: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

// Индекс для быстрого поиска
recipeSchema.index({ userId: 1, createdAt: -1 });

// Виртуальное поле для получения изображения как base64
recipeSchema.virtual('imageUrl').get(function() {
  if (this.image && this.imageContentType) {
    return `data:${this.imageContentType};base64,${this.image.toString('base64')}`;
  }
  return null;
});

// Включаем виртуальные поля в JSON
recipeSchema.set('toJSON', { virtuals: true });
recipeSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Recipe', recipeSchema);
