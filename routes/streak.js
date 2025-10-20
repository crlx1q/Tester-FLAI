const express = require('express');
const authMiddleware = require('../middleware/auth');
const Database = require('../utils/database');

const router = express.Router();

// Записать ежедневный визит (для streak)
router.post('/', authMiddleware, (req, res) => {
  try {
    const user = Database.getUserById(req.userId);
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastVisit = user.lastVisit ? new Date(user.lastVisit) : null;
    const lastVisitDay = lastVisit ? new Date(lastVisit.getFullYear(), lastVisit.getMonth(), lastVisit.getDate()) : null;
    
    let newStreak = user.streak || 0;
    let maxStreak = user.maxStreak || 0;
    
    if (lastVisitDay) {
      const diffDays = Math.floor((today - lastVisitDay) / (1000 * 60 * 60 * 24));
      
      if (diffDays === 0) {
        // Сегодня уже была активность - просто возвращаем текущий streak
        return res.json({
          success: true,
          streak: newStreak,
          maxStreak: maxStreak
        });
      } else if (diffDays === 1) {
        // Вчера была активность - продолжаем streak
        newStreak = (newStreak === 0) ? 1 : newStreak + 1;
        if (newStreak > maxStreak) {
          maxStreak = newStreak;
        }
      } else {
        // Пропустили дни - сброс streak на 0, активность начнется с 1
        newStreak = 1;
        if (maxStreak === 0) {
          maxStreak = 1;
        }
      }
    } else {
      // Первый визит - начинаем с 1
      newStreak = 1;
      maxStreak = 1;
    }
    
    Database.updateUser(req.userId, {
      streak: newStreak,
      maxStreak: maxStreak,
      lastVisit: now.toISOString()
    });
    
    res.json({
      success: true,
      streak: newStreak,
      maxStreak: maxStreak
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
