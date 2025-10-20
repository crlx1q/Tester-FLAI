const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const authMiddleware = require('../middleware/auth');
const { checkRecipeLimit } = require('../middleware/usage-limits');
const { checkFileSizeLimit, compressImage } = require('../middleware/image-compression');
const Database = require('../utils/database');
const { generateRecipe } = require('../utils/ai');

const router = express.Router();

// Настройка multer для загрузки изображений рецептов
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/recipes');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `recipe-${Date.now()}-${Math.random().toString(36).substring(7)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const upload = multer({ 
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB временный лимит (будет проверяться в middleware)
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = file.mimetype ? allowedTypes.test(file.mimetype) : true;
    
    if (mimetype || extname) {
      return cb(null, true);
    }
    cb(new Error('Только изображения разрешены!'));
  }
});

// Системные рецепты от FoodLens AI
const mockRecipes = [
  {
    _id: 'system_1',
    userId: 'system',
    name: 'Салат с киноа и авокадо',
    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=300&fit=crop',
    calories: 350,
    macros: { protein: 12, fat: 18, carbs: 38 },
    protein: 12,
    fat: 18,
    carbs: 38,
    prepTime: 15,
    difficulty: 'Легко',
    servings: 2,
    cookTime: '00:15',
    goal: 'lose_weight',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Киноа', amount: '100', unit: 'г', calories: 120 },
      { name: 'Авокадо', amount: '1', unit: 'шт', calories: 160 },
      { name: 'Помидоры черри', amount: '10', unit: 'шт', calories: 30 },
      { name: 'Огурец', amount: '1', unit: 'шт', calories: 15 },
      { name: 'Оливковое масло', amount: '2', unit: 'ст.л', calories: 20 },
      { name: 'Лимонный сок', amount: '1', unit: 'ст.л', calories: 5 }
    ],
    instructions: [
      'Отварите киноа в подсоленной воде 12-15 минут до готовности',
      'Нарежьте авокадо кубиками, помидоры черри пополам',
      'Огурец нарежьте тонкими кружочками',
      'Смешайте все ингредиенты в большой миске',
      'Заправьте оливковым маслом и лимонным соком',
      'Посолите и поперчите по вкусу, подавайте сразу'
    ],
    createdAt: new Date('2024-01-01').toISOString()
  },
  {
    _id: 'system_2',
    userId: 'system',
    name: 'Запечённый лосось со спаржей',
    imageUrl: 'https://images.unsplash.com/photo-1485921325833-c519f76c4927?w=400&h=300&fit=crop',
    calories: 480,
    macros: { protein: 42, fat: 28, carbs: 12 },
    protein: 42,
    fat: 28,
    carbs: 12,
    prepTime: 25,
    difficulty: 'Средне',
    servings: 2,
    cookTime: '00:25',
    goal: 'lose_weight',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Филе лосося', amount: '300', unit: 'г', calories: 350 },
      { name: 'Спаржа', amount: '200', unit: 'г', calories: 40 },
      { name: 'Лимон', amount: '1', unit: 'шт', calories: 20 },
      { name: 'Чеснок', amount: '2', unit: 'зубчика', calories: 10 },
      { name: 'Оливковое масло', amount: '2', unit: 'ст.л', calories: 40 },
      { name: 'Свежий укроп', amount: '20', unit: 'г', calories: 5 }
    ],
    instructions: [
      'Разогрейте духовку до 200°C',
      'Выложите лосось и спаржу на противень с пергаментом',
      'Сбрызните оливковым маслом, добавьте измельченный чеснок',
      'Выжмите сок половины лимона сверху',
      'Посолите, поперчите и посыпьте укропом',
      'Запекайте 18-20 минут до готовности рыбы',
      'Подавайте с дольками лимона'
    ],
    createdAt: new Date('2024-01-02').toISOString()
  },
  {
    _id: 'system_3',
    userId: 'system',
    name: 'Куриная грудка с рисом',
    imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400&h=300&fit=crop',
    calories: 520,
    macros: { protein: 45, fat: 8, carbs: 62 },
    protein: 45,
    fat: 8,
    carbs: 62,
    prepTime: 30,
    difficulty: 'Легко',
    servings: 2,
    cookTime: '00:30',
    goal: 'gain_muscle',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Куриная грудка', amount: '300', unit: 'г', calories: 330 },
      { name: 'Рис басмати', amount: '100', unit: 'г', calories: 130 },
      { name: 'Брокколи', amount: '150', unit: 'г', calories: 50 },
      { name: 'Соевый соус', amount: '2', unit: 'ст.л', calories: 10 }
    ],
    instructions: [
      'Отварите рис согласно инструкции на упаковке',
      'Нарежьте куриную грудку кубиками',
      'Обжарьте курицу на антипригарной сковороде 8-10 минут',
      'Отварите брокколи на пару 5-7 минут',
      'Смешайте все ингредиенты',
      'Полейте соевым соусом и подавайте горячим'
    ],
    createdAt: new Date('2024-01-03').toISOString()
  },
  {
    _id: 'system_4',
    userId: 'system',
    name: 'Овсянка с фруктами и орехами',
    imageUrl: 'https://images.unsplash.com/photo-1517673400267-0251440da88b?w=400&h=300&fit=crop',
    calories: 380,
    macros: { protein: 12, fat: 14, carbs: 52 },
    protein: 12,
    fat: 14,
    carbs: 52,
    prepTime: 10,
    difficulty: 'Легко',
    servings: 1,
    cookTime: '00:10',
    goal: 'maintain_weight',
    allergies: ['nuts'],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Овсяные хлопья', amount: '50', unit: 'г', calories: 185 },
      { name: 'Молоко', amount: '200', unit: 'мл', calories: 120 },
      { name: 'Банан', amount: '1', unit: 'шт', calories: 105 },
      { name: 'Грецкие орехи', amount: '20', unit: 'г', calories: 130 },
      { name: 'Мед', amount: '1', unit: 'ч.л', calories: 20 },
      { name: 'Корица', amount: '1', unit: 'щепотка', calories: 0 }
    ],
    instructions: [
      'Залейте овсяные хлопья молоком',
      'Варите на среднем огне 5-7 минут, помешивая',
      'Нарежьте банан кружочками',
      'Измельчите грецкие орехи',
      'Выложите овсянку в тарелку',
      'Украсьте бананом, орехами, медом и корицей'
    ],
    createdAt: new Date('2024-01-04').toISOString()
  },
  {
    _id: 'system_5',
    userId: 'system',
    name: 'Греческий йогурт с медом',
    imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=300&fit=crop',
    calories: 220,
    macros: { protein: 18, fat: 5, carbs: 28 },
    protein: 18,
    fat: 5,
    carbs: 28,
    prepTime: 5,
    difficulty: 'Легко',
    servings: 1,
    cookTime: '00:05',
    goal: 'maintain_weight',
    allergies: ['lactose'],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Греческий йогурт', amount: '200', unit: 'г', calories: 130 },
      { name: 'Мед', amount: '2', unit: 'ст.л', calories: 60 },
      { name: 'Черника', amount: '50', unit: 'г', calories: 30 }
    ],
    instructions: [
      'Выложите греческий йогурт в красивую пиалу',
      'Полейте медом сверху',
      'Добавьте свежую чернику',
      'При желании посыпьте семенами чиа',
      'Подавайте немедленно'
    ],
    createdAt: new Date('2024-01-05').toISOString()
  },
  {
    _id: 'system_6',
    userId: 'system',
    name: 'Тунец с овощами',
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop',
    calories: 320,
    macros: { protein: 38, fat: 12, carbs: 18 },
    protein: 38,
    fat: 12,
    carbs: 18,
    prepTime: 20,
    difficulty: 'Легко',
    servings: 2,
    cookTime: '00:20',
    goal: 'lose_weight',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Стейк тунца', amount: '250', unit: 'г', calories: 250 },
      { name: 'Болгарский перец', amount: '1', unit: 'шт', calories: 30 },
      { name: 'Цуккини', amount: '1', unit: 'шт', calories: 30 },
      { name: 'Лук красный', amount: '0.5', unit: 'шт', calories: 10 }
    ],
    instructions: [
      'Нарежьте все овощи тонкими полосками',
      'Обжарьте овощи на сковороде 5 минут',
      'Посолите и поперчите стейк тунца',
      'Обжарьте тунец по 2-3 минуты с каждой стороны',
      'Выложите тунец на овощи',
      'Подавайте горячим с лимоном'
    ],
    createdAt: new Date('2024-01-06').toISOString()
  },
  {
    _id: 'system_7',
    userId: 'system',
    name: 'Смузи боул с ягодами',
    imageUrl: 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=400&h=300&fit=crop',
    calories: 290,
    macros: { protein: 8, fat: 7, carbs: 48 },
    protein: 8,
    fat: 7,
    carbs: 48,
    prepTime: 10,
    difficulty: 'Легко',
    servings: 1,
    cookTime: '00:10',
    goal: 'maintain_weight',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Замороженные ягоды', amount: '200', unit: 'г', calories: 120 },
      { name: 'Банан', amount: '1', unit: 'шт', calories: 105 },
      { name: 'Йогурт натуральный', amount: '100', unit: 'мл', calories: 60 },
      { name: 'Гранола', amount: '30', unit: 'г', calories: 130 },
      { name: 'Семена чиа', amount: '1', unit: 'ч.л', calories: 20 }
    ],
    instructions: [
      'Смешайте в блендере ягоды, банан и йогурт до однородности',
      'Вылейте смузи в глубокую тарелку',
      'Украсьте гранолой',
      'Посыпьте семенами чиа',
      'Добавьте свежие ягоды для декора',
      'Подавайте немедленно с ложкой'
    ],
    createdAt: new Date('2024-01-07').toISOString()
  },
  {
    _id: 'system_8',
    userId: 'system',
    name: 'Стейк с овощами гриль',
    imageUrl: 'https://images.unsplash.com/photo-1558030006-450675393462?w=400&h=300&fit=crop',
    calories: 550,
    macros: { protein: 52, fat: 32, carbs: 15 },
    protein: 52,
    fat: 32,
    carbs: 15,
    prepTime: 35,
    difficulty: 'Средне',
    servings: 2,
    cookTime: '00:35',
    goal: 'gain_muscle',
    allergies: [],
    author: {
      name: 'FoodLens AI',
      isVerified: true,
      isPro: false
    },
    ingredients: [
      { name: 'Говяжий стейк', amount: '300', unit: 'г', calories: 450 },
      { name: 'Баклажан', amount: '1', unit: 'шт', calories: 35 },
      { name: 'Кабачок', amount: '1', unit: 'шт', calories: 30 },
      { name: 'Болгарский перец', amount: '2', unit: 'шт', calories: 60 },
      { name: 'Оливковое масло', amount: '2', unit: 'ст.л', calories: 40 },
      { name: 'Розмарин', amount: '2', unit: 'веточки', calories: 0 }
    ],
    instructions: [
      'Достаньте стейк из холодильника за 30 минут до готовки',
      'Нарежьте овощи толстыми кружками',
      'Сбрызните овощи маслом, посолите и поперчите',
      'Разогрейте гриль или сковороду-гриль',
      'Обжарьте стейк по 4-5 минут с каждой стороны для medium',
      'Одновременно жарьте овощи 3-4 минуты с каждой стороны',
      'Дайте стейку отдохнуть 5 минут перед подачей',
      'Нарежьте стейк, подавайте с овощами и розмарином'
    ],
    createdAt: new Date('2024-01-08').toISOString()
  }
];

// Получить рецепты с фильтрами (общедоступные - все пользовательские + системные)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { goal, allergies } = req.query;
    
    // Получаем ВСЕ рецепты пользователей (общедоступные)
    const allUserRecipes = await Database.getRecipes();
    
    // Добавляем информацию об авторе к каждому пользовательскому рецепту
    const userRecipesWithAuthors = await Promise.all(allUserRecipes.map(async recipe => {
      const author = await Database.getUserById(recipe.userId);
      return {
        ...recipe,
        author: author ? {
          name: author.name || 'Пользователь',
          isVerified: false,
          isPro: author.isPro || false
        } : {
          name: 'Неизвестный пользователь',
          isVerified: false,
          isPro: false
        }
      };
    }));
    
    // Объединяем с системными рецептами
    let filteredRecipes = [...mockRecipes, ...userRecipesWithAuthors];
    
    // Фильтр по цели
    if (goal) {
      filteredRecipes = filteredRecipes.filter(r => r.goal === goal);
    }
    
    // Фильтр по аллергиям
    if (allergies) {
      const allergyList = allergies.split(',');
      filteredRecipes = filteredRecipes.filter(r => {
        return !r.allergies || !r.allergies.some(a => allergyList.includes(a));
      });
    }
    
    res.json({
      success: true,
      recipes: filteredRecipes
    });
  } catch (error) {
    console.error('Get recipes error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения рецептов'
    });
  }
});

// Создать рецепт через AI
router.post('/generate', authMiddleware, checkRecipeLimit, upload.single('image'), checkFileSizeLimit, compressImage, async (req, res) => {
  try {
    const { dishName } = req.body;
    
    if (!dishName) {
      return res.status(400).json({
        success: false,
        message: 'Название блюда обязательно'
      });
    }
    
    let imageBase64 = null;
    let imageUrl = null;
    
    // Если есть фото, конвертируем в base64
    if (req.file) {
      const imageBuffer = fs.readFileSync(req.file.path);
      imageBase64 = imageBuffer.toString('base64');
      imageUrl = `/uploads/recipes/${req.file.filename}`;
    }
    
    console.log(`🤖 Генерация рецепта для: ${dishName}`);
    
    // Генерируем рецепт через AI
    const aiRecipe = await generateRecipe(dishName, imageBase64);
    
    // Сохраняем в базу
    const recipeData = {
      userId: req.userId,
      name: aiRecipe.name || dishName,
      imageUrl: imageUrl,
      calories: aiRecipe.calories || 0,
      macros: aiRecipe.macros || { protein: 0, fat: 0, carbs: 0 },
      protein: aiRecipe.macros?.protein || 0,
      fat: aiRecipe.macros?.fat || 0,
      carbs: aiRecipe.macros?.carbs || 0,
      prepTime: aiRecipe.prepTime || 30,
      difficulty: aiRecipe.difficulty || 'Средне',
      servings: aiRecipe.servings || 1,
      cookTime: aiRecipe.cookTime || '00:30',
      ingredients: aiRecipe.ingredients || [],
      instructions: aiRecipe.instructions || [],
      isFavorite: false
    };
    
    const newRecipe = await Database.createRecipe(recipeData);
    
    // Увеличиваем счетчик использования
    await Database.incrementUserUsage(req.userId, 'recipes');
    
    console.log('✅ Рецепт создан:', newRecipe._id);
    
    // Преобразуем в объект с виртуальными полями
    const recipeObject = newRecipe.toObject();
    console.log('📝 Recipe name:', recipeObject.name);
    console.log('🖼️ Recipe has imageUrl:', !!recipeObject.imageUrl);
    
    res.json({
      success: true,
      recipe: recipeObject
    });
  } catch (error) {
    console.error('Generate recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка генерации рецепта: ' + error.message
    });
  }
});

// Получить детали рецепта
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const recipe = await Database.getRecipeById(req.params.id);
    
    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Рецепт не найден'
      });
    }
    
    res.json({
      success: true,
      recipe
    });
  } catch (error) {
    console.error('Get recipe details error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения рецепта'
    });
  }
});

// Обновить рецепт
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const recipe = await Database.getRecipeById(req.params.id);
    
    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Рецепт не найден'
      });
    }
    
    if (recipe.userId.toString() !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет прав на редактирование'
      });
    }
    
    const updatedRecipe = await Database.updateRecipe(req.params.id, req.body);
    
    res.json({
      success: true,
      recipe: updatedRecipe
    });
  } catch (error) {
    console.error('Update recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка обновления рецепта'
    });
  }
});

// Удалить рецепт
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const recipe = await Database.getRecipeById(req.params.id);
    
    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Рецепт не найден'
      });
    }
    
    if (recipe.userId.toString() !== req.userId) {
      return res.status(403).json({
        success: false,
        message: 'Нет прав на удаление'
      });
    }
    
    // Изображения хранятся в MongoDB как Buffer, удаление файлов не требуется
    await Database.deleteRecipe(req.params.id);
    
    res.json({
      success: true,
      message: 'Рецепт удален'
    });
  } catch (error) {
    console.error('Delete recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления рецепта'
    });
  }
});

// Добавить рецепт в избранное
router.post('/:id/favorite', authMiddleware, async (req, res) => {
  try {
    const recipeId = req.params.id;
    const userId = req.userId;
    
    const user = await Database.getUserById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    // Инициализируем массив избранных рецептов если его нет
    if (!user.favoriteRecipes) {
      user.favoriteRecipes = [];
    }
    
    // Проверяем, не добавлен ли уже рецепт
    if (user.favoriteRecipes.includes(recipeId)) {
      return res.json({
        success: true,
        message: 'Рецепт уже в избранном'
      });
    }
    
    // Добавляем в избранное
    user.favoriteRecipes.push(recipeId);
    await Database.updateUser(userId, { favoriteRecipes: user.favoriteRecipes });
    
    res.json({
      success: true,
      message: 'Рецепт добавлен в избранное'
    });
  } catch (error) {
    console.error('Add to favorites error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка добавления в избранное'
    });
  }
});

// Удалить рецепт из избранного
router.delete('/:id/favorite', authMiddleware, async (req, res) => {
  try {
    const recipeId = req.params.id;
    const userId = req.userId;
    
    const user = await Database.getUserById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Пользователь не найден'
      });
    }
    
    if (!user.favoriteRecipes) {
      user.favoriteRecipes = [];
    }
    
    // Удаляем из избранного
    user.favoriteRecipes = user.favoriteRecipes.filter(id => id !== recipeId);
    await Database.updateUser(userId, { favoriteRecipes: user.favoriteRecipes });
    
    res.json({
      success: true,
      message: 'Рецепт удален из избранного'
    });
  } catch (error) {
    console.error('Remove from favorites error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка удаления из избранного'
    });
  }
});

// Получить избранные рецепты пользователя
router.get('/favorites/my', authMiddleware, async (req, res) => {
  try {
    const user = await Database.getUserById(req.userId);
    if (!user || !user.favoriteRecipes) {
      return res.json({
        success: true,
        recipes: []
      });
    }
    
    // Получаем детали каждого избранного рецепта
    const favoriteRecipes = [];
    
    for (const recipeId of user.favoriteRecipes) {
      // Ищем в системных рецептах
      let recipe = mockRecipes.find(r => r._id === recipeId);
      
      // Если не нашли, ищем в пользовательских
      if (!recipe) {
        recipe = await Database.getRecipeById(recipeId);
        if (recipe) {
          const author = await Database.getUserById(recipe.userId);
          recipe = {
            ...recipe,
            author: author ? {
              name: author.name || 'Пользователь',
              isVerified: false,
              isPro: author.isPro || false
            } : {
              name: 'Неизвестный пользователь',
              isVerified: false,
              isPro: false
            }
          };
        }
      }
      
      if (recipe) {
        favoriteRecipes.push(recipe);
      }
    }
    
    res.json({
      success: true,
      recipes: favoriteRecipes
    });
  } catch (error) {
    console.error('Get favorite recipes error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка получения избранных рецептов'
    });
  }
});

module.exports = router;
