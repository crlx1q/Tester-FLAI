const express = require('express');
const router = express.Router();
const Friendship = require('../models/Friendship');
const Notification = require('../models/Notification');
const Database = require('../utils/database');
const authMiddleware = require('../middleware/auth');

// Поиск пользователей по username
router.get('/search', authMiddleware, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.length < 2) {
      return res.json({ success: true, users: [] });
    }

    const users = await Database.searchUsersByUsername(q, req.userId);
    
    // Проверяем статус дружбы для каждого найденного пользователя
    const usersWithStatus = await Promise.all(users.map(async (user) => {
      const friendship = await Friendship.findOne({
        $or: [
          { from: req.userId, to: user._id },
          { from: user._id, to: req.userId }
        ]
      });

      let friendStatus = 'none';
      if (friendship) {
        if (friendship.status === 'accepted') {
          friendStatus = 'friends';
        } else if (friendship.from.toString() === req.userId) {
          friendStatus = 'sent';
        } else {
          friendStatus = 'received';
        }
      }

      return {
        _id: user._id,
        username: user.username,
        name: user.name,
        streak: user.streak,
        goal: user.goal,
        friendStatus
      };
    }));

    res.json({ success: true, users: usersWithStatus });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ success: false, message: 'Ошибка поиска' });
  }
});

// Отправить запрос дружбы
router.post('/request/:userId', authMiddleware, async (req, res) => {
  try {
    const targetUserId = req.params.userId;

    if (targetUserId === req.userId) {
      return res.status(400).json({ success: false, message: 'Нельзя добавить себя в друзья' });
    }

    // Проверяем, нет ли уже дружбы
    const existing = await Friendship.findOne({
      $or: [
        { from: req.userId, to: targetUserId },
        { from: targetUserId, to: req.userId }
      ]
    });

    if (existing) {
      if (existing.status === 'accepted') {
        return res.status(400).json({ success: false, message: 'Вы уже друзья' });
      }
      return res.status(400).json({ success: false, message: 'Запрос уже отправлен' });
    }

    // Создаём запрос дружбы
    const friendship = new Friendship({
      from: req.userId,
      to: targetUserId,
      status: 'pending'
    });
    await friendship.save();

    // Создаём уведомление для получателя
    const sender = await Database.getUserById(req.userId);
    await new Notification({
      userId: targetUserId,
      type: 'friend_request',
      title: 'Новый запрос в друзья',
      body: `@${sender.username || sender.name} хочет добавить вас в друзья`,
      data: { friendshipId: friendship._id, fromUserId: req.userId }
    }).save();

    res.json({ success: true, message: 'Запрос отправлен', friendshipId: friendship._id });
  } catch (error) {
    console.error('Friend request error:', error);
    res.status(500).json({ success: false, message: 'Ошибка отправки запроса' });
  }
});

// Принять запрос дружбы
router.post('/accept/:friendshipId', authMiddleware, async (req, res) => {
  try {
    const friendship = await Friendship.findOne({
      _id: req.params.friendshipId,
      to: req.userId,
      status: 'pending'
    });

    if (!friendship) {
      return res.status(404).json({ success: false, message: 'Запрос не найден' });
    }

    friendship.status = 'accepted';
    await friendship.save();

    // Уведомление отправителю
    const accepter = await Database.getUserById(req.userId);
    await new Notification({
      userId: friendship.from,
      type: 'friend_accepted',
      title: 'Запрос принят',
      body: `@${accepter.username || accepter.name} принял(а) ваш запрос в друзья`,
      data: { friendshipId: friendship._id }
    }).save();

    res.json({ success: true, message: 'Запрос принят' });
  } catch (error) {
    console.error('Accept friend error:', error);
    res.status(500).json({ success: false, message: 'Ошибка принятия запроса' });
  }
});

// Отклонить/удалить запрос дружбы
router.post('/reject/:friendshipId', authMiddleware, async (req, res) => {
  try {
    const friendship = await Friendship.findOneAndDelete({
      _id: req.params.friendshipId,
      $or: [{ to: req.userId }, { from: req.userId }]
    });

    if (!friendship) {
      return res.status(404).json({ success: false, message: 'Запрос не найден' });
    }

    res.json({ success: true, message: 'Запрос отклонён' });
  } catch (error) {
    console.error('Reject friend error:', error);
    res.status(500).json({ success: false, message: 'Ошибка отклонения запроса' });
  }
});

// Удалить из друзей
router.delete('/:friendshipId', authMiddleware, async (req, res) => {
  try {
    const friendship = await Friendship.findOneAndDelete({
      _id: req.params.friendshipId,
      $or: [{ from: req.userId }, { to: req.userId }]
    });

    if (!friendship) {
      return res.status(404).json({ success: false, message: 'Дружба не найдена' });
    }

    res.json({ success: true, message: 'Удалено из друзей' });
  } catch (error) {
    console.error('Delete friend error:', error);
    res.status(500).json({ success: false, message: 'Ошибка удаления' });
  }
});

// Список друзей (accepted)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const friendships = await Friendship.find({
      $or: [{ from: req.userId }, { to: req.userId }],
      status: 'accepted'
    }).populate('from', 'username name streak goal')
      .populate('to', 'username name streak goal');

    const friends = friendships.map(f => {
      const friend = f.from._id.toString() === req.userId ? f.to : f.from;
      return {
        friendshipId: f._id,
        _id: friend._id,
        username: friend.username,
        name: friend.name,
        streak: friend.streak,
        goal: friend.goal
      };
    });

    res.json({ success: true, friends });
  } catch (error) {
    console.error('Get friends error:', error);
    res.status(500).json({ success: false, message: 'Ошибка получения друзей' });
  }
});

// Входящие запросы
router.get('/requests', authMiddleware, async (req, res) => {
  try {
    const requests = await Friendship.find({
      to: req.userId,
      status: 'pending'
    }).populate('from', 'username name streak goal');

    const formatted = requests.map(r => ({
      friendshipId: r._id,
      _id: r.from._id,
      username: r.from.username,
      name: r.from.name,
      streak: r.from.streak,
      goal: r.from.goal,
      createdAt: r.createdAt
    }));

    res.json({ success: true, requests: formatted });
  } catch (error) {
    console.error('Get requests error:', error);
    res.status(500).json({ success: false, message: 'Ошибка получения запросов' });
  }
});

// Прогресс друга (калории, КБЖУ, вода, streak, блюда за сегодня)
router.get('/:userId/progress', authMiddleware, async (req, res) => {
  try {
    const friendUserId = req.params.userId;

    // Проверяем что это действительно друг
    const friendship = await Friendship.findOne({
      $or: [
        { from: req.userId, to: friendUserId },
        { from: friendUserId, to: req.userId }
      ],
      status: 'accepted'
    });

    if (!friendship) {
      return res.status(403).json({ success: false, message: 'Это не ваш друг' });
    }

    const friend = await Database.getUserById(friendUserId);
    if (!friend) {
      return res.status(404).json({ success: false, message: 'Пользователь не найден' });
    }

    // Получаем данные друга за сегодня
    const todayFoods = await Database.getFoodsByDate(friendUserId, new Date());
    
    let totalCalories = 0;
    let totalMacros = { protein: 0, fat: 0, carbs: 0 };
    todayFoods.forEach(food => {
      totalCalories += food.calories || 0;
      if (food.macros) {
        totalMacros.protein += food.macros.protein || 0;
        totalMacros.fat += food.macros.fat || 0;
        totalMacros.carbs += food.macros.carbs || 0;
      }
    });

    // Вода
    const { getDateString, getCurrentDate } = require('../utils/timezone');
    const todayStr = getDateString(getCurrentDate());
    const waterData = await Database.getWaterIntakeByDate(friendUserId, todayStr);

    res.json({
      success: true,
      friend: {
        _id: friend._id,
        username: friend.username,
        name: friend.name,
        goal: friend.goal,
        dailyCalories: friend.dailyCalories,
        macros: friend.macros,
        streak: friend.streak,
        waterTarget: friend.waterTarget
      },
      today: {
        totalCalories,
        totalMacros,
        foods: todayFoods.map(f => ({
          name: f.name,
          calories: f.calories,
          macros: f.macros,
          mealType: f.mealType,
          timestamp: f.timestamp
        })),
        water: waterData ? waterData.amount : 0
      }
    });
  } catch (error) {
    console.error('Get friend progress error:', error);
    res.status(500).json({ success: false, message: 'Ошибка получения прогресса' });
  }
});

module.exports = router;
