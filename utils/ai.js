const axios = require('axios');

// Используем те же переменные что и в ai-service.js
const GEMINI_API_KEY = process.env.AI_API_KEY;
const GEMINI_MODEL = 'gemini-2.5-flash-lite'; // Gemini 2.5 Flash Lite (Stable)
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

/**
 * Wrapper для axios запросов с retry логикой при 503 ошибках
 */
async function axiosWithRetry(config, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      if (attempt > 1) {
        const delay = 2000 * attempt; // Увеличивающаяся задержка: 2s, 4s, 6s
        console.log(`🔄 Повторная попытка ${attempt}/${maxRetries} через ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
      
      const response = await axios(config);
      return response; // Успех!
      
    } catch (error) {
      const is503 = error.response?.status === 503;
      const isLastAttempt = attempt === maxRetries;
      
      if (is503 && !isLastAttempt) {
        console.log(`⚠️ Gemini API перегружен (503), попытка ${attempt}/${maxRetries}`);
        continue; // Повторяем
      }
      
      // Если это последняя попытка или не 503 - выбрасываем ошибку
      throw error;
    }
  }
}

/**
 * Анализ текстового описания блюда через Gemini AI
 */
async function analyzeTextDescription(description) {
  const prompt = `Ты профессиональный диетолог и эксперт по питанию. Проанализируй описание блюда и верни точные данные о калорийности и БЖУ.

ОПИСАНИЕ: "${description}"

ИНСТРУКЦИИ:
1. Определи что это за блюдо/блюда
2. Посчитай количество порций (если указано "два бургера" - учти оба)
3. Оцени размер порции (маленькая/средняя/большая)
4. Рассчитай ТОЧНЫЕ калории и БЖУ на основе стандартных данных о продуктах
5. Если это НЕ ЕДА (например кот, стол, человек) - укажи calories: 0
6. Подбери подходящий эмодзи (один символ)

ВАЖНО: Используй реальные данные о калорийности продуктов. Например:
- Яблоко среднее: ~95 ккал
- Банан: ~105 ккал  
- Куриная грудка 100г: ~165 ккал
- Овсянка порция: ~150 ккал

Верни ТОЛЬКО JSON без объяснений:
{
  "name": "Название блюда с количеством",
  "emoji": "🍽️",
  "calories": число,
  "macros": {
    "protein": число_грамм,
    "fat": число_грамм,
    "carbs": число_грамм
  },
  "healthScore": число_от_0_до_100
}

ОЦЕНКА ПОЛЕЗНОСТИ (healthScore):
- 0-30: Вредная еда (фастфуд, сладости, жареное)
- 31-60: Средняя (смешанные блюда, умеренно полезные)
- 61-100: Полезная еда (овощи, фрукты, нежирное мясо, каши)`;

  try {
    const response = await axios.post(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json'
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 60000 // ✅ Увеличили с 30 до 60 секунд для медленного интернета
      }
    );

    const text = response.data.candidates[0].content.parts[0].text;
    
    // Пробуем распарсить напрямую (если responseMimeType работает)
    try {
      let result = JSON.parse(text);
      
      // Если ответ - массив, берем первый элемент
      if (Array.isArray(result) && result.length > 0) {
        result = result[0];
      }
      
      return result;
    } catch {
      // Если не получилось, ищем JSON в тексте
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        let result = JSON.parse(jsonMatch[0]);
        
        // Если ответ - массив, берем первый элемент
        if (Array.isArray(result) && result.length > 0) {
          result = result[0];
        }
        
        return result;
      }
      throw new Error('Не удалось извлечь JSON из ответа');
    }
  } catch (error) {
    console.error('Gemini API Error:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Анализ изображения блюда через Gemini Vision
 */
async function analyzeImageFood(imageBase64) {
  const prompt = `Ты профессиональный диетолог и эксперт по питанию. Проанализируй изображение и определи что на нем.

ИНСТРУКЦИИ:
1. Внимательно изучи изображение
2. Если это ЕДА или НАПИТОК:
   - Определи название блюда/напитка
   - Посчитай количество порций (если видно 2 бургера - укажи "Два бургера")
   - Оцени размер порции визуально
   - Определи состав блюда (ингредиенты)
   - Рассчитай ТОЧНЫЕ калории и БЖУ на основе:
     * Типа продуктов
     * Размера порции
     * Способа приготовления (жареное/вареное/запеченное)
   - Подбери подходящий эмодзи

3. Если это НЕ ЕДА (кот, собака, человек, стол, телефон и т.д.):
   - name: "Не еда! [что изображено]"
   - calories: 0
   - все макросы: 0
   - emoji: "❌"

ВАЖНО: Будь точным в расчетах. Используй реальные данные о калорийности:
- Пицца кусок: ~250-300 ккал
- Бургер: ~500-700 ккал
- Салат: ~150-250 ккал
- Паста порция: ~350-450 ккал

Верни ТОЛЬКО JSON:
{
  "name": "Название с количеством",
  "emoji": "🍕",
  "calories": число,
  "macros": {
    "protein": число_грамм,
    "fat": число_грамм,
    "carbs": число_грамм
  },
  "healthScore": число_от_0_до_100
}

ОЦЕНКА ПОЛЕЗНОСТИ (healthScore):
- 0-30: Вредная еда (фастфуд, сладости, жареное в масле)
- 31-60: Средняя (смешанные блюда, умеренно полезные)
- 61-100: Полезная еда (овощи, фрукты, нежирное мясо, каши, рыба)`;

  try {
    const response = await axios.post(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        contents: [{
          parts: [
            {
              text: prompt
            },
            {
              inline_data: {
                mime_type: "image/jpeg",
                data: imageBase64
              }
            }
          ]
        }],
        generationConfig: {
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json'
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 60000 // ✅ Увеличили с 30 до 60 секунд для медленного интернета
      }
    );

    const text = response.data.candidates[0].content.parts[0].text;
    
    // Пробуем распарсить напрямую
    try {
      let result = JSON.parse(text);
      
      // Если ответ - массив, берем первый элемент
      if (Array.isArray(result) && result.length > 0) {
        result = result[0];
      }
      
      return result;
    } catch {
      // Если не получилось, ищем JSON в тексте
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        let result = JSON.parse(jsonMatch[0]);
        
        // Если ответ - массив, берем первый элемент
        if (Array.isArray(result) && result.length > 0) {
          result = result[0];
        }
        
        return result;
      }
      throw new Error('Не удалось извлечь JSON из ответа');
    }
  } catch (error) {
    console.error('Gemini Vision API Error:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Генерация рецепта через Gemini AI на основе названия блюда и фото
 */
async function generateRecipe(dishName, imageBase64 = null) {
  const prompt = `Ты профессиональный шеф-повар и диетолог. Создай детальный рецепт для блюда: "${dishName}".

ИНСТРУКЦИИ:
1. Проанализируй ${imageBase64 ? 'изображение блюда и ' : ''}название
2. Определи точное время приготовления (prepTime в минутах)
3. Определи уровень сложности: "Легко", "Средне", "Сложно"
4. Определи время готовки (например: "02:15" для 2 часов 15 минут)
5. Рассчитай БЖУ и калории на 1 порцию
6. Составь детальный список ингредиентов с количеством и калориями
7. Создай пошаговые инструкции по приготовлению

ВАЖНО: Будь точным и конкретным. Укажи реальные данные.

Верни ТОЛЬКО JSON:
{
  "name": "Полное название блюда",
  "calories": число_калорий_на_порцию,
  "macros": {
    "protein": число_грамм,
    "fat": число_грамм,
    "carbs": число_грамм
  },
  "prepTime": число_минут,
  "difficulty": "Легко|Средне|Сложно",
  "servings": количество_порций,
  "cookTime": "ЧЧ:ММ",
  "ingredients": [
    {
      "name": "Название ингредиента",
      "amount": "Количество",
      "calories": число_ккал,
      "unit": "шт|г|мл|ст.л|ч.л"
    }
  ],
  "instructions": [
    "Шаг 1: Подробное описание",
    "Шаг 2: Подробное описание",
    "..."
  ]
}`;

  try {
    const parts = [{ text: prompt }];
    
    if (imageBase64) {
      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: imageBase64
        }
      });
    }

    const response = await axios.post(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 4096,
          responseMimeType: 'application/json'
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 60000
      }
    );

    const text = response.data.candidates[0].content.parts[0].text;
    
    try {
      let result = JSON.parse(text);
      
      if (Array.isArray(result) && result.length > 0) {
        result = result[0];
      }
      
      return result;
    } catch {
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        let result = JSON.parse(jsonMatch[0]);
        
        if (Array.isArray(result) && result.length > 0) {
          result = result[0];
        }
        
        return result;
      }
      throw new Error('Не удалось извлечь JSON из ответа');
    }
  } catch (error) {
    console.error('Gemini Recipe Generation Error:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Анализ изображения блюда с учетом нового названия через Gemini Vision
 */
async function analyzeImageFoodWithName(imageBase64, newName) {
  const prompt = `Ты профессиональный диетолог и эксперт по питанию. Пользователь указал, что на изображении "${newName}". Проанализируй изображение и рассчитай точные данные.

ИНСТРУКЦИИ:
1. Внимательно изучи изображение
2. Пользователь говорит что это: "${newName}"
3. Используй изображение для определения:
   - Размера порции (визуально)
   - Количества порций
   - Способа приготовления (жареное/вареное/запеченное)
4. Рассчитай ТОЧНЫЕ калории и БЖУ на основе:
   - Названия блюда: "${newName}"
   - Визуального размера порции с изображения
   - Состава блюда
5. Подбери подходящий эмодзи

ВАЖНО: Используй реальные данные о калорийности продуктов:
- Пицца кусок: ~250-300 ккал
- Бургер: ~500-700 ккал
- Салат: ~150-250 ккал
- Паста порция: ~350-450 ккал

Верни ТОЛЬКО JSON:
{
  "name": "Название блюда",
  "emoji": "🍕",
  "calories": число,
  "macros": {
    "protein": число_грамм,
    "fat": число_грамм,
    "carbs": число_грамм
  },
  "healthScore": число_от_0_до_100
}

ОЦЕНКА ПОЛЕЗНОСТИ (healthScore):
- 0-30: Вредная еда (фастфуд, сладости, жареное в масле)
- 31-60: Средняя (смешанные блюда, умеренно полезные)
- 61-100: Полезная еда (овощи, фрукты, нежирное мясо, каши, рыба)`;

  try {
    const response = await axios.post(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        contents: [{
          parts: [
            {
              text: prompt
            },
            {
              inline_data: {
                mime_type: "image/jpeg",
                data: imageBase64
              }
            }
          ]
        }],
        generationConfig: {
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json'
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 60000 // ✅ Увеличили с 30 до 60 секунд для медленного интернета
      }
    );

    const text = response.data.candidates[0].content.parts[0].text;
    
    // Пробуем распарсить напрямую
    try {
      let result = JSON.parse(text);
      
      // Если ответ - массив, берем первый элемент
      if (Array.isArray(result) && result.length > 0) {
        result = result[0];
      }
      
      return result;
    } catch {
      // Если не получилось, ищем JSON в тексте
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        let result = JSON.parse(jsonMatch[0]);
        
        // Если ответ - массив, берем первый элемент
        if (Array.isArray(result) && result.length > 0) {
          result = result[0];
        }
        
        return result;
      }
      throw new Error('Не удалось извлечь JSON из ответа');
    }
  } catch (error) {
    console.error('Gemini Vision API Error:', error.response?.data || error.message);
    throw error;
  }
}

module.exports = {
  analyzeTextDescription,
  analyzeImageFood,
  analyzeImageFoodWithName,
  generateRecipe
};
