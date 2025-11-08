const Database = require('../utils/database');
const { getCurrentDate, TIMEZONE } = require('../utils/timezone');

// Лимиты для Free и Pro пользователей
const LIMITS = {
  free: {
    photos: 2,
    messages: 10,
    recipes: 1
  },
  pro: {
    photos: 50,
    messages: 100,
    recipes: 30
  }
};

// Middleware для проверки лимита фотографий
const checkPhotoLimit = async (req, res, next) => {
  try {
    const user = await Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем тип подписки
    const subscriptionType = user.subscriptionType || 'free';
    
    // Проверяем не истек ли Pro (если есть)
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(user.subscriptionExpiresAt);
      
      // console.log('🔍 Проверка подписки (photos):', {
      //   now_Almaty: now.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   now_UTC: now.toISOString(),
      //   expiresAt_Almaty: expiresAt.toLocaleString('ru-RU', { timeZone: TIMEZONE }),
      //   expiresAt_UTC: expiresAt.toISOString(),
      //   expired: now > expiresAt
      // });
      
      if (now > expiresAt) {
        // Подписка истекла, переводим на free
        console.log('⚠️ Подписка истекла, переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].photos;
    const usage = await Database.getUserUsage(req.userId);
    
    if (usage.photosCount >= limit) {
      return res.status(403).json({
        success: false,
        message: `Достигнут лимит загрузки фотографий (${limit} в день). ${user.subscriptionType === 'free' ? 'Перейдите на Pro для 50 фото в день!' : 'Попробуйте завтра.'}`,
        limitReached: true,
        limitType: 'photos',
        current: usage.photosCount,
        max: limit,
        isPro: user.subscriptionType === 'pro'
      });
    }
    
    // Передаем информацию о лимитах в следующий middleware
    req.userLimits = {
      subscriptionType: user.subscriptionType === 'pro' ? 'pro' : 'free',
      isPro: user.subscriptionType === 'pro',
      photos: { current: usage.photosCount, max: limit }
    };
    
    next();
  } catch (error) {
    console.error('Check photo limit error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка проверки лимитов'
    });
  }
};

// Middleware для проверки лимита сообщений
const checkMessageLimit = async (req, res, next) => {
  try {
    const user = await Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем тип подписки и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(user.subscriptionExpiresAt);
      if (now > expiresAt) {
        console.log('⚠️ Подписка истекла (messages), переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].messages;
    const usage = await Database.getUserUsage(req.userId);
    
    if (usage.messagesCount >= limit) {
      return res.status(403).json({
        success: false,
        message: `Достигнут лимит сообщений (${limit} в день). ${user.subscriptionType === 'free' ? 'Перейдите на Pro для 100 сообщений в день!' : 'Попробуйте завтра.'}`,
        limitReached: true,
        limitType: 'messages',
        current: usage.messagesCount,
        max: limit,
        isPro: user.subscriptionType === 'pro'
      });
    }
    
    req.userLimits = {
      subscriptionType: user.subscriptionType === 'pro' ? 'pro' : 'free',
      isPro: user.subscriptionType === 'pro',
      messages: { current: usage.messagesCount, max: limit }
    };
    
    next();
  } catch (error) {
    console.error('Check message limit error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка проверки лимитов'
    });
  }
};

// Middleware для проверки лимита рецептов
const checkRecipeLimit = async (req, res, next) => {
  try {
    const user = await Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем тип подписки и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(user.subscriptionExpiresAt);
      if (now > expiresAt) {
        console.log('⚠️ Подписка истекла (recipes), переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].recipes;
    const usage = await Database.getUserUsage(req.userId);
    
    if (usage.recipesCount >= limit) {
      return res.status(403).json({
        success: false,
        message: `Достигнут лимит создания рецептов (${limit} в день). ${user.subscriptionType === 'free' ? 'Перейдите на Pro для 30 рецептов в день!' : 'Попробуйте завтра.'}`,
        limitReached: true,
        limitType: 'recipes',
        current: usage.recipesCount,
        max: limit,
        isPro: user.subscriptionType === 'pro'
      });
    }
    
    req.userLimits = {
      subscriptionType: user.subscriptionType === 'pro' ? 'pro' : 'free',
      isPro: user.subscriptionType === 'pro',
      recipes: { current: usage.recipesCount, max: limit }
    };
    
    next();
  } catch (error) {
    console.error('Check recipe limit error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка проверки лимитов'
    });
  }
};

// Middleware для проверки Pro подписки
const requirePro = async (req, res, next) => {
  try {
    const user = await Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем подписку и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const now = new Date(); // UTC время (правильное для сравнения дат)
      const expiresAt = new Date(user.subscriptionExpiresAt);
      if (now > expiresAt) {
        console.log('⚠️ Подписка истекла (requirePro), переводим на FREE');
        await Database.updateUserSubscription(user._id, 'free', null);
        return res.status(403).json({
          success: false,
          message: 'Эта функция доступна только для Pro пользователей. Ваша подписка истекла.',
          requiresPro: true
        });
      }
    }
    
    if (user.subscriptionType !== 'pro') {
      return res.status(403).json({
        success: false,
        message: 'Эта функция доступна только для Pro пользователей',
        requiresPro: true
      });
    }
    
    next();
  } catch (error) {
    console.error('Require pro error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка проверки подписки'
    });
  }
};

module.exports = {
  checkPhotoLimit,
  checkMessageLimit,
  checkRecipeLimit,
  requirePro,
  LIMITS
};
