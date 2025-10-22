const axios = require('axios');
const fs = require('fs');

// Функция анализа еды через AI
async function analyzeFood(imagePath, user) {
  try {
    // Проверяем наличие API ключа
    if (!process.env.AI_API_KEY || process.env.AI_API_KEY === 'your_gemini_api_key_here' || process.env.AI_API_KEY === 'your_ai_api_key_here') {
      console.warn('Gemini API key not configured, using mock data');
      return getMockFoodAnalysis();
    }
    
    const provider = process.env.AI_PROVIDER || 'gemini';
    
    if (provider === 'gemini') {
      // Интеграция с Google Gemini 2.5 Flash Experimental
      const imageBase64 = fs.readFileSync(imagePath, { encoding: 'base64' });
      
      const response = await axios.post(
        `${process.env.AI_API_URL}?key=${process.env.AI_API_KEY}`,
        {
          contents: [{
            parts: [
              {
                text: `Проанализируй еду на изображении и верни СТРОГО В ФОРМАТЕ JSON:
{
  "name": "точное название блюда на русском языке",
  "calories": число_калорий_целое_число,
  "macros": {
    "protein": граммы_белка,
    "fat": граммы_жиров,
    "carbs": граммы_углеводов
  }
}

ВАЖНО:
1. Всегда указывай КОНКРЕТНОЕ название блюда (например: "Шаурма с курицей", "Три донера", "Бутерброд с колбасой")
2. Никогда не используй общие названия типа "Еда", "Блюдо", "Неизвестно"
3. Верни ТОЛЬКО валидный JSON, без markdown, без комментариев, без дополнительного текста`
              },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: imageBase64
                }
              }
            ]
          }]
        },
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );
      
      const aiText = response.data.candidates[0].content.parts[0].text;
      console.log('AI raw response:', aiText);
      
      // Извлекаем JSON из ответа
      let jsonMatch = aiText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        // Валидация обязательных полей
        if (!parsed.name || parsed.name.trim() === '') {
          console.error('AI returned empty name, using fallback');
          parsed.name = 'Блюдо';
        }
        console.log('Parsed food data:', parsed);
        return parsed;
      }
      
      const parsed = JSON.parse(aiText);
      if (!parsed.name || parsed.name.trim() === '') {
        parsed.name = 'Блюдо';
      }
      return parsed;
      
    } else {
      // OpenAI fallback
      const imageBase64 = fs.readFileSync(imagePath, { encoding: 'base64' });
      
      const response = await axios.post(
        process.env.AI_API_URL,
        {
          model: process.env.AI_MODEL,
          messages: [
            {
              role: 'system',
              content: 'Ты эксперт-нутрициолог. Анализируй изображения еды и возвращай JSON с полями: name (название блюда), calories (калории), macros (объект с carbs, protein, fat в граммах).'
            },
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: 'Проанализируй это блюдо и верни точные данные о калориях и макронутриентах в формате JSON.'
                },
                {
                  type: 'image_url',
                  image_url: {
                    url: `data:image/jpeg;base64,${imageBase64}`
                  }
                }
              ]
            }
          ],
          max_tokens: 300
        },
        {
          headers: {
            'Authorization': `Bearer ${process.env.AI_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
      
      const aiResponse = response.data.choices[0].message.content;
      return JSON.parse(aiResponse);
    }
    
  } catch (error) {
    console.error('AI analysis error:', error.message);
    // Возвращаем моковые данные при ошибке
    return getMockFoodAnalysis();
  }
}

// Функция AI чата
async function chatWithAI(message, context) {
  try {
    // Проверяем наличие API ключа
    if (!process.env.AI_API_KEY || process.env.AI_API_KEY === 'your_gemini_api_key_here' || process.env.AI_API_KEY === 'your_ai_api_key_here') {
      console.warn('AI API key not configured, using mock response');
      return getMockChatResponse(message, context);
    }
    
    const provider = process.env.AI_PROVIDER || 'gemini';
    
    // Формируем системный промпт
    const systemPrompt = `Ты AI-нутрициолог в приложении FoodLens AI. Ты умный, эмпатичный эксперт по питанию.

ПРАВИЛА:
- Отвечай КРАТКО (2-4 предложения)
- БЕЗ приветствий в середине разговора
- Помни контекст предыдущих сообщений
- Давай конкретные, персонализированные советы
- Используй данные пользователя для расчетов и рекомендаций

ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
- Имя: ${context.user.name}
- Возраст: ${context.user.age || 'не указан'} лет
- Рост: ${context.user.height || 'не указан'} см
- Вес: ${context.user.weight || 'не указан'} кг
- Пол: ${context.user.gender === 'male' ? 'Мужской' : context.user.gender === 'female' ? 'Женский' : 'не указан'}
- Цель: ${context.user.goal || 'не указана'}
- Уровень активности: ${context.user.activityLevel || 'не указан'}
- Целевой вес: ${context.user.targetWeight || 'не указан'} кг
- Норма калорий: ${context.user.dailyCalories}ккал
- Макросы: Белки ${context.user.macros.protein}г, Жиры ${context.user.macros.fat}г, Углеводы ${context.user.macros.carbs}г
- Норма воды: ${context.user.waterTarget ? (context.user.waterTarget / 100) + ' стаканов' : 'не указана'}
- Аллергии: ${context.user.allergies && context.user.allergies.length > 0 ? context.user.allergies.join(', ') : 'нет'}

СЕГОДНЯШНИЙ РАЦИОН:
${context.todayFoods.length > 0 ? context.todayFoods.map(f => `- ${f.name}: ${f.calories}ккал (Б${f.macros.protein}г Ж${f.macros.fat}г У${f.macros.carbs}г)`).join('\n') : '- Пока ничего не съедено'}

Используй ВСЕ эти данные для персонализированных советов!`;

    if (provider === 'gemini') {
      // Формируем историю чата для Gemini
      const contents = [];
      
      // Добавляем историю
      if (context.chatHistory && context.chatHistory.length > 0) {
        context.chatHistory.slice(-6).forEach(msg => { // Последние 6 сообщений
          contents.push({
            role: msg.isUser ? 'user' : 'model',
            parts: [{ text: msg.text }]
          });
        });
      }
      
      // Добавляем текущее сообщение
      contents.push({
        role: 'user',
        parts: [{ text: message }]
      });
      
      // Gemini 2.5 Flash Experimental API
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-exp:generateContent?key=${process.env.AI_API_KEY}`,
        {
          systemInstruction: {
            parts: [{ text: systemPrompt }]
          },
          contents: contents,
          generationConfig: {
            temperature: 0.8,
            maxOutputTokens: 600,
            topP: 0.95
          }
        },
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );
      
      return response.data.candidates[0].content.parts[0].text;
    } else {
      // OpenAI fallback
      const response = await axios.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: 'gpt-4',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: message }
          ],
          max_tokens: 500,
          temperature: 0.7
        },
        {
          headers: {
            'Authorization': `Bearer ${process.env.AI_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
      
      return response.data.choices[0].message.content;
    }
    
  } catch (error) {
    console.error('AI chat error:', error.message);
    return getMockChatResponse(message, context);
  }
}

// Моковые данные для тестирования
function getMockFoodAnalysis() {
  const foods = [
    { name: 'Греческий салат', calories: 250, macros: { carbs: 12, protein: 8, fat: 18 } },
    { name: 'Куриная грудка с овощами', calories: 380, macros: { carbs: 24, protein: 42, fat: 12 } },
    { name: 'Омлет с сыром', calories: 320, macros: { carbs: 5, protein: 22, fat: 24 } },
    { name: 'Паста Карбонара', calories: 520, macros: { carbs: 58, protein: 18, fat: 24 } },
    { name: 'Смузи боул', calories: 280, macros: { carbs: 48, protein: 8, fat: 6 } }
  ];
  
  return foods[Math.floor(Math.random() * foods.length)];
}

function getMockChatResponse(message, context) {
  const totalCalories = context.todayFoods.reduce((sum, f) => sum + f.calories, 0);
  const remaining = context.user.dailyCalories - totalCalories;
  
  if (message.toLowerCase().includes('белок') || message.toLowerCase().includes('protein')) {
    const totalProtein = context.todayFoods.reduce((sum, f) => sum + f.macros.protein, 0);
    return `Сегодня вы съели ${totalProtein}г белка. Ваша цель — ${context.user.macros.protein}г. ${
      totalProtein < context.user.macros.protein 
        ? `Рекомендую добавить в рацион курицу, рыбу или творог, чтобы достичь цели.` 
        : `Отличный результат! Вы уже достигли своей цели по белку.`
    }`;
  }
  
  if (message.toLowerCase().includes('калори') || message.toLowerCase().includes('сколько')) {
    return `Сегодня вы съели ${totalCalories} ккал из ${context.user.dailyCalories} ккал. ${
      remaining > 0 
        ? `У вас осталось ${remaining} ккал.` 
        : `Вы немного превысили норму.`
    } Продолжайте в том же духе!`;
  }
  
  if (message.toLowerCase().includes('совет') || message.toLowerCase().includes('рекоменд')) {
    return `На основе вашего рациона сегодня, я рекомендую добавить больше овощей и зелени. Это поможет вам чувствовать себя сытым и получать больше витаминов без лишних калорий.`;
  }
  
  return `Спасибо за ваш вопрос! Я проанализировал ваш рацион за сегодня. Вы на правильном пути к своей цели "${context.user.goal}". Продолжайте следить за питанием и не забывайте про водный баланс! 💪`;
}

// Функция AI чата с изображением
async function chatWithAIImage(imagePath, message, context) {
  try {
    // Проверяем наличие API ключа
    if (!process.env.AI_API_KEY || process.env.AI_API_KEY === 'your_gemini_api_key_here' || process.env.AI_API_KEY === 'your_ai_api_key_here') {
      console.warn('AI API key not configured, using mock response');
      return `Я вижу на фото блюдо. ${getMockChatResponse(message, context)}`;
    }
    
    const provider = process.env.AI_PROVIDER || 'gemini';
    
    // Формируем системный промпт
    const systemPrompt = `Ты AI-нутрициолог в приложении FoodLens AI. Анализируй изображения еды и отвечай на вопросы пользователя.

ПРАВИЛА:
- Отвечай КРАТКО (2-5 предложений)
- Используй Markdown: * для списков, ** для жирного
- Анализируй еду на фото
- Давай конкретные, персонализированные советы по питанию
- Используй данные пользователя для расчетов

ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
- Имя: ${context.user.name}
- Возраст: ${context.user.age || 'не указан'} лет
- Рост: ${context.user.height || 'не указан'} см
- Вес: ${context.user.weight || 'не указан'} кг
- Пол: ${context.user.gender === 'male' ? 'Мужской' : context.user.gender === 'female' ? 'Женский' : 'не указан'}
- Цель: ${context.user.goal || 'не указана'}
- Уровень активности: ${context.user.activityLevel || 'не указан'}
- Целевой вес: ${context.user.targetWeight || 'не указан'} кг
- Норма калорий: ${context.user.dailyCalories}ккал
- Макросы: Белки ${context.user.macros.protein}г, Жиры ${context.user.macros.fat}г, Углеводы ${context.user.macros.carbs}г
- Аллергии: ${context.user.allergies && context.user.allergies.length > 0 ? context.user.allergies.join(', ') : 'нет'}`;

    const imageBase64 = fs.readFileSync(imagePath, { encoding: 'base64' });
    
    if (provider === 'gemini') {
      // Gemini 2.5 Flash Experimental with Vision
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-exp:generateContent?key=${process.env.AI_API_KEY}`,
        {
          systemInstruction: {
            parts: [{ text: systemPrompt }]
          },
          contents: [{
            parts: [
              { text: message || 'Что это за еда? Сколько в ней калорий и макронутриентов?' },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: imageBase64
                }
              }
            ]
          }],
          generationConfig: {
            temperature: 0.8,
            maxOutputTokens: 800,
            topP: 0.95
          }
        },
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );
      
      return response.data.candidates[0].content.parts[0].text;
    } else {
      // OpenAI fallback
      const response = await axios.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: 'gpt-4-vision-preview',
          messages: [
            { role: 'system', content: systemPrompt },
            { 
              role: 'user', 
              content: [
                { type: 'text', text: message || 'Что это за еда? Сколько в ней калорий?' },
                { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
              ]
            }
          ],
          max_tokens: 500,
          temperature: 0.7
        },
        {
          headers: {
            'Authorization': `Bearer ${process.env.AI_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
      
      return response.data.choices[0].message.content;
    }
    
  } catch (error) {
    console.error('AI chat with image error:', error.message);
    return `Я вижу на фото блюдо. ${getMockChatResponse(message, context)}`;
  }
}

module.exports = {
  analyzeFood,
  chatWithAI,
  chatWithAIImage
};
