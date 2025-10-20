const mongoose = require('mongoose');

const waterIntakeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  date: {
    type: String, // Формат: YYYY-MM-DD
    required: true,
    index: true
  },
  amount: {
    type: Number,
    default: 0,
    min: 0
  }
}, {
  timestamps: true
});

// Уникальный индекс для пары userId + date
waterIntakeSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('WaterIntake', waterIntakeSchema);
