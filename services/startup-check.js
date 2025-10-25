const User = require('../models/User');

/**
 * Сервис для автоматической проверки и обновления данных пользователей при запуске сервера
 * Проверяет streak и subscription для всех пользователей
 */
class StartupCheckService {
  /**
   * Запуск всех проверок
   */
  static async runAllChecks() {
    console.log('🔍 Запуск проверки данных пользователей...');
    
    try {
      await this.checkAndUpdateStreaks();
      await this.checkAndUpdateSubscriptions();
      
      console.log('✅ Проверка данных завершена успешно');
    } catch (error) {
      console.error('❌ Ошибка при проверке данных:', error);
    }
  }

  /**
   * Проверка и обновление streak для всех пользователей
   * Логика: если прошло более 2 дней с lastVisit, сбрасываем streak на 0
   * Запас 1 день: если сегодня 21, а lastVisit был 20 - не сбрасываем
   *                если сегодня 22, а lastVisit был 20 - сбрасываем (прошло 2 дня)
   */
  static async checkAndUpdateStreaks() {
    console.log('📅 Проверка streak...');
    
    try {
      const users = await User.find({ lastVisit: { $ne: null } });
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      let updatedCount = 0;
      
      for (const user of users) {
        const lastVisit = new Date(user.lastVisit);
        const lastVisitDay = new Date(lastVisit.getFullYear(), lastVisit.getMonth(), lastVisit.getDate());
        
        // Вычисляем разницу в днях
        const diffDays = Math.floor((today - lastVisitDay) / (1000 * 60 * 60 * 24));
        
        // Если прошло более 1 дня (то есть 2 или больше), сбрасываем streak
        if (diffDays > 1 && user.streak > 0) {
          user.streak = 0;
          await user.save();
          updatedCount++;
          console.log(`  ↳ Streak сброшен для ${user.email} (последний визит: ${lastVisit.toISOString().split('T')[0]}, прошло дней: ${diffDays})`);
        }
      }
      
      if (updatedCount > 0) {
        console.log(`  ✅ Обновлено streak у ${updatedCount} пользователей`);
      } else {
        console.log(`  ✓ Все streak актуальны`);
      }
    } catch (error) {
      console.error('  ❌ Ошибка проверки streak:', error);
      throw error;
    }
  }

  /**
   * Проверка и обновление подписок для всех пользователей
   * Если подписка истекла, переключаем на free
   */
  static async checkAndUpdateSubscriptions() {
    console.log('💎 Проверка подписок...');
    
    try {
      const users = await User.find({ 
        subscriptionType: 'pro',
        subscriptionExpiresAt: { $ne: null }
      });
      
      const now = new Date();
      let updatedCount = 0;
      
      for (const user of users) {
        const expiresAt = new Date(user.subscriptionExpiresAt);
        
        // Если подписка истекла
        if (now > expiresAt) {
          user.subscriptionType = 'free';
          user.isPro = false;
          user.subscriptionExpiresAt = null;
          await user.save();
          updatedCount++;
          console.log(`  ↳ Подписка истекла для ${user.email} (истекла: ${expiresAt.toISOString().split('T')[0]})`);
        }
      }
      
      if (updatedCount > 0) {
        console.log(`  ✅ Обновлено подписок у ${updatedCount} пользователей`);
      } else {
        console.log(`  ✓ Все подписки актуальны`);
      }
    } catch (error) {
      console.error('  ❌ Ошибка проверки подписок:', error);
      throw error;
    }
  }

  /**
   * Вычисление оставшихся дней подписки
   * @param {Date} expiresAt - дата истечения подписки
   * @returns {number} количество дней до истечения (или 0 если истекла)
   */
  static calculateRemainingDays(expiresAt) {
    if (!expiresAt) return 0;
    
    const now = new Date();
    const expires = new Date(expiresAt);
    
    // Устанавливаем время на начало дня для корректного подсчета
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const expiresStart = new Date(expires.getFullYear(), expires.getMonth(), expires.getDate());
    
    const diffMs = expiresStart - todayStart;
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
    
    return Math.max(0, diffDays);
  }
}

module.exports = StartupCheckService;

