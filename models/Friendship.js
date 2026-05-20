const mongoose = require('mongoose');

const friendshipSchema = new mongoose.Schema({
  from: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  to: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'accepted'],
    default: 'pending'
  }
}, {
  timestamps: true
});

// Индекс для быстрого поиска
friendshipSchema.index({ from: 1, to: 1 }, { unique: true });
friendshipSchema.index({ to: 1, status: 1 });
friendshipSchema.index({ from: 1, status: 1 });

module.exports = mongoose.model('Friendship', friendshipSchema);
