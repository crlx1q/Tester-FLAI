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
  healthScore: {
    type: Number,
    default: 50,
    min: 0,
    max: 100
  },
  mealType: {
    type: String,
    enum: ['Завтрак', 'Обед', 'Ужин', 'Перекус'],
    default: 'Перекус'
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: true
});

// Индекс для быстрого поиска по пользователю и дате
foodSchema.index({ userId: 1, timestamp: -1 });

// Виртуальное поле для получения изображения как base64
foodSchema.virtual('imageUrl').get(function() {
  if (this.image && this.imageContentType) {
    return `data:${this.imageContentType};base64,${this.image.toString('base64')}`;
  }
  return null;
});

// Включаем виртуальные поля в JSON
foodSchema.set('toJSON', { virtuals: true });
foodSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Food', foodSchema);
