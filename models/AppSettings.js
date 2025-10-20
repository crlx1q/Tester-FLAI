const mongoose = require('mongoose');

const appSettingsSchema = new mongoose.Schema({
  registrationEnabled: {
    type: Boolean,
    default: true
  },
  currentVersion: {
    type: String,
    default: '1.2.0'
  },
  updateDescription: {
    type: String,
    default: ''
  },
  hasUpdate: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('AppSettings', appSettingsSchema);
