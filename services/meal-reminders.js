const Database = require('../utils/database-mongo');
const { sendPushNotification } = require('./firebase');

const MEAL_MESSAGES = {
  breakfast: {
    title: 'Время завтрака',
    body: 'Не забудьте записать свой завтрак в FoodLens AI',
  },
  lunch: {
    title: 'Время обеда',
    body: 'Пора записать обед! Отсканируйте или опишите блюдо',
  },
  dinner: {
    title: 'Время ужина',
    body: 'Запишите свой ужин, чтобы не пропустить данные за день',
  },
};

// Check every minute if any user has a reminder at this time
async function checkMealReminders() {
  const now = new Date();
  const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padLeft ? now.getMinutes().toString().padStart(2, '0') : now.getMinutes().toString().padStart(2, '0')}`;

  try {
    const User = require('../models/User');
    
    // Find users who have meal reminders enabled and have a reminder at this exact time
    const meals = ['breakfast', 'lunch', 'dinner'];
    
    for (const meal of meals) {
      const query = {
        [`mealReminders.${meal}`]: currentTime,
        'notificationSettings.mealReminders': true,
        fcmToken: { $ne: null, $exists: true },
      };
      
      const users = await User.find(query).select('fcmToken').lean();
      
      if (users.length > 0) {
        const msg = MEAL_MESSAGES[meal];
        console.log(`Sending ${meal} reminders to ${users.length} users at ${currentTime}`);
        
        for (const user of users) {
          if (user.fcmToken) {
            await sendPushNotification(user.fcmToken, msg.title, msg.body, { type: 'meal_reminder', meal });
          }
        }
      }
    }
  } catch (error) {
    console.error('Meal reminder check error:', error.message);
  }
}

// Start the reminder scheduler (runs every 60 seconds)
function startMealReminderScheduler() {
  console.log('Meal reminder scheduler started');
  
  // Run every 60 seconds, aligned to the minute
  const now = new Date();
  const msUntilNextMinute = (60 - now.getSeconds()) * 1000 - now.getMilliseconds();
  
  // First run aligned to next full minute
  setTimeout(() => {
    checkMealReminders();
    // Then run every 60 seconds
    setInterval(checkMealReminders, 60 * 1000);
  }, msUntilNextMinute);
}

module.exports = { startMealReminderScheduler, checkMealReminders };
