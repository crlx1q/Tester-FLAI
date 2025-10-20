const Database = require('../utils/database');

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
const checkPhotoLimit = (req, res, next) => {
  try {
    const user = Database.getUserById(req.userId);
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
      const expiresAt = new Date(user.subscriptionExpiresAt);
      const now = new Date();
      if (now > expiresAt) {
        // Подписка истекла, переводим на free
        Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].photos;
    const usage = Database.getUserUsage(req.userId);
    
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
const checkMessageLimit = (req, res, next) => {
  try {
    const user = Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем тип подписки и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const expiresAt = new Date(user.subscriptionExpiresAt);
      const now = new Date();
      if (now > expiresAt) {
        Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].messages;
    const usage = Database.getUserUsage(req.userId);
    
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
const checkRecipeLimit = (req, res, next) => {
  try {
    const user = Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем тип подписки и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const expiresAt = new Date(user.subscriptionExpiresAt);
      const now = new Date();
      if (now > expiresAt) {
        Database.updateUserSubscription(user._id, 'free', null);
        user.subscriptionType = 'free';
        user.isPro = false;
      }
    }
    
    const limit = LIMITS[user.subscriptionType === 'pro' ? 'pro' : 'free'].recipes;
    const usage = Database.getUserUsage(req.userId);
    
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
const requirePro = (req, res, next) => {
  try {
    const user = Database.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Проверяем подписку и срок действия
    const subscriptionType = user.subscriptionType || 'free';
    if (subscriptionType === 'pro' && user.subscriptionExpiresAt) {
      const expiresAt = new Date(user.subscriptionExpiresAt);
      const now = new Date();
      if (now > expiresAt) {
        Database.updateUserSubscription(user._id, 'free', null);
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
