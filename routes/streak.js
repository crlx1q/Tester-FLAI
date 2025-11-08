const express = require('express');
const authMiddleware = require('../middleware/auth');
const Database = require('../utils/database');
const { getCurrentDate, getTodayStart, getLocalDay, getDaysDifference } = require('../utils/timezone');

const router = express.Router();

// Записать ежедневный визит (для streak)
router.post('/', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    
    const now = new Date(); // UTC время для сохранения в базу
    const today = getTodayStart();
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? getLocalDay(lastVisit) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    let streakStatus = 'active';
    
    if (lastVisitDay) {
      const diffDays = getDaysDifference(today, lastVisitDay);
      
      if (diffDays === 0) {
        // Сегодня уже была активность - возвращаем текущий streak
        streakStatus = 'active';
        return res.json({
          success: true,
          streak: newStreak,
          maxStreak: maxStreak,
          streakStatus: streakStatus
        });
      } else if (diffDays === 1) {
        // Вчера была активность - продолжаем серию (из серого в активный)
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
        streakStatus = 'active';
      } else {
        // Пропустили 2+ дня - начинаем новую серию с 1
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
        streakStatus = 'active';
      }
    } else {
      // Первый визит - начинаем с 1
      newStreak = 1;
      maxStreak = 1;
      streakStatus = 'active';
    }
    
    await Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
    res.json({
      success: true,
      streak: newStreak,
      maxStreak: maxStreak,
      streakStatus: streakStatus
    });
  } catch (error) {
    console.error('Streak update error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления streak'
    });
  }
});

module.exports = router;
