const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const Database = require('../utils/database');
const authMiddleware = require('../middleware/auth');

// Получить уведомления
router.get('/', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    const notifications = await Notification.find({ userId: req.userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const unreadCount = await Notification.countDocuments({
      userId: req.userId,
      read: false
    });

    res.json({
      success: true,
      notifications,
      unreadCount,
      page,
      limit
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ success: false, message: 'Ошибка получения уведомлений' });
  }
});

// Количество непрочитанных
router.get('/unread-count', authMiddleware, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.userId,
      read: false
    });

    res.json({ success: true, count });
  } catch (error) {
    console.error('Unread count error:', error);
    res.status(500).json({ success: false, message: 'Ошибка' });
  }
});

// Отметить как прочитанное
router.post('/mark-read/:id', authMiddleware, async (req, res) => {
  try {
    await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      { $set: { read: true } }
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ success: false, message: 'Ошибка' });
  }
});

// Отметить все как прочитанные
router.post('/mark-all-read', authMiddleware, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.userId, read: false },
      { $set: { read: true } }
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Mark all read error:', error);
    res.status(500).json({ success: false, message: 'Ошибка' });
  }
});

// Удалить уведомление
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await Notification.findOneAndDelete({
      _id: req.params.id,
      userId: req.userId
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ success: false, message: 'Ошибка удаления' });
  }
});

// Обновить настройки уведомлений
router.post('/settings', authMiddleware, async (req, res) => {
  try {
    const { friendActivity, mealReminders, updates, reminderTimes } = req.body;

    const updateData = {};
    if (typeof friendActivity === 'boolean') updateData['notificationSettings.friendActivity'] = friendActivity;
    if (typeof mealReminders === 'boolean') updateData['notificationSettings.mealReminders'] = mealReminders;
    if (typeof updates === 'boolean') updateData['notificationSettings.updates'] = updates;
    if (reminderTimes) {
      if (reminderTimes.breakfast !== undefined) updateData['mealReminders.breakfast'] = reminderTimes.breakfast;
      if (reminderTimes.lunch !== undefined) updateData['mealReminders.lunch'] = reminderTimes.lunch;
      if (reminderTimes.dinner !== undefined) updateData['mealReminders.dinner'] = reminderTimes.dinner;
    }

    await Database.updateUser(req.userId, updateData);

    res.json({ success: true, message: 'Настройки сохранены' });
  } catch (error) {
    console.error('Notification settings error:', error);
    res.status(500).json({ success: false, message: 'Ошибка сохранения настроек' });
  }
});

// Обновить FCM token
router.post('/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { token } = req.body;
    await Database.updateUser(req.userId, { fcmToken: token });
    res.json({ success: true });
  } catch (error) {
    console.error('FCM token update error:', error);
    res.status(500).json({ success: false, message: 'Ошибка' });
  }
});

module.exports = router;
