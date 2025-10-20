const mongoose = require('mongoose');

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
    required: true
  },
  avatar: {
    type: Buffer, // Храним изображение как Buffer в MongoDB
    default: null
  },
  avatarContentType: {
    type: String,
    default: null
  },
  subscriptionType: {
    type: String,
    enum: ['free', 'pro'],
    default: 'free'
  },
  isPro: {
    type: Boolean,
    default: false
  },
  subscriptionExpiresAt: {
    type: Date,
    default: null
  },
  streak: {
    type: Number,
    default: 0
  },
  maxStreak: {
    type: Number,
    default: 0
  },
  lastVisit: {
    type: Date,
    default: null
  },
  onboardingCompleted: {
    type: Boolean,
    default: false
  },
  goal: {
    type: String,
    default: null
  },
  goalDescription: {
    type: String,
    default: null
  },
  targetWeight: {
    type: Number,
    default: null
  },
  waterTarget: {
    type: Number,
    default: 2000 // мл
  },
  gender: {
    type: String,
    default: null
  },
  age: {
    type: Number,
    default: null
  },
  height: {
    type: Number,
    default: null
  },
  weight: {
    type: Number,
    default: null
  },
  activityLevel: {
    type: String,
    default: null
  },
  allergies: [{
    type: String
  }],
  dailyCalories: {
    type: Number,
    default: 2000
  },
  macros: {
    carbs: { type: Number, default: 270 },
    protein: { type: Number, default: 130 },
    fat: { type: Number, default: 58 }
  },
  usage: {
    date: { type: String, default: null },
    photosCount: { type: Number, default: 0 },
    messagesCount: { type: Number, default: 0 },
    recipesCount: { type: Number, default: 0 }
  },
  favoriteFoods: [{
    name: String,
    calories: Number,
    macros: {
      protein: Number,
      fat: Number,
      carbs: Number
    },
    addedAt: { type: Date, default: Date.now }
  }],
  favoriteRecipes: [{
    type: String
  }]
}, {
  timestamps: true
});

// Виртуальное поле для получения avatar как base64
userSchema.virtual('avatarUrl').get(function() {
  if (this.avatar && this.avatarContentType) {
    return `data:${this.avatarContentType};base64,${this.avatar.toString('base64')}`;
  }
  return null;
});

// Включаем виртуальные поля в JSON
userSchema.set('toJSON', { virtuals: true });
userSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('User', userSchema);
