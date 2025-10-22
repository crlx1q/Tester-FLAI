const express = require('express');
const axios = require('axios');
const authMiddleware = require('../middleware/auth');
const Database = require('../utils/database');

const router = express.Router();

// Завершение onboarding с AI-персонализацией
router.post('/complete', authMiddleware, async (req, res) => {
  try {
    const { age, height, weight, gender, goal, activityLevel, allergies } = req.body;
    
    if (!age || !height || !weight || !gender || !goal || !activityLevel) {
      return res.status(400).json({
        success: false,
        message: 'Все поля обязательны для заполнения'
      });
    }
    
    // Формируем промпт для AI
    const prompt = `Ты профессиональный диетолог и фитнес-тренер. Проанализируй данные пользователя и создай персонализированный план питания.

ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
- Возраст: ${age} лет
- Рост: ${height} см
- Вес: ${weight} кг
- Пол: ${gender === 'male' ? 'Мужской' : 'Женский'}
- Цель: ${goal}
- Уровень активности: ${activityLevel}
${allergies && allergies.length > 0 ? `- Аллергии: ${allergies.join(', ')}` : ''}

ЗАДАЧА:
1. Рассчитай оптимальную дневную норму калорий
2. Рассчитай макронутриенты (белки, жиры, углеводы) в граммах
3. Рассчитай норму воды в день (в стаканах по 100мл)
4. Определи целевой вес (если цель - похудение/набор массы)
5. Создай КОРОТКОЕ название цели (1-2 слова, например: "Похудение", "Набор массы", "Поддержание формы")
6. Создай ПОЛНОЕ описание цели (1-2 предложения с деталями и мотивацией)

ВАЖНО:
- Учитывай базовый метаболизм (BMR) и уровень активности
- Для похудения создавай дефицит калорий 300-500 ккал
- Для набора массы создавай профицит калорий 300-500 ккал
- Белки: 1.6-2.2г на кг веса для набора массы, 1.2-1.6г для похудения
- Жиры: 20-30% от общих калорий
- Углеводы: остальное

ФОРМАТ ОТВЕТА (строго JSON):
{
  "dailyCalories": число,
  "macros": {
    "protein": число в граммах,
    "fat": число в граммах,
    "carbs": число в граммах
  },
  "waterGlasses": число стаканов по 100мл,
  "targetWeight": число (целевой вес в кг),
  "goalTitle": "короткое название цели (1-2 слова)",
  "goalDescription": "полное описание цели (1-2 предложения)"
}`;

    // Запрос к AI (используем Gemini 2.5 Flash как в остальном проекте)
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.AI_API_KEY}`,
      {
        systemInstruction: {
          parts: [{ text: 'Ты профессиональный диетолог и фитнес-тренер. Отвечай ТОЛЬКО в формате JSON.' }]
        },
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 500
        }
      },
      {
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );
    
    const responseText = response.data.candidates[0].content.parts[0].text;
    
    // Парсим JSON из ответа
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('AI не вернул корректный JSON');
    }
    
    const aiPlan = JSON.parse(jsonMatch[0]);
    
    // Обновляем пользователя
    const updatedUser = await Database.updateUser(req.userId, {
      age: parseInt(age),
      height: parseInt(height),
      weight: parseFloat(weight),
      gender,
      goal: aiPlan.goalTitle, // Короткое название цели
      goalDescription: aiPlan.goalDescription, // Полное описание цели
      activityLevel,
      allergies: allergies || [],
      dailyCalories: aiPlan.dailyCalories,
      macros: aiPlan.macros,
      targetWeight: aiPlan.targetWeight,
      waterTarget: aiPlan.waterGlasses * 100, // Переводим в мл
      onboardingCompleted: true
    });
    
    // Удаляем пароль из ответа
    const userObject = updatedUser.toObject();
    delete userObject.password;
    
    res.json({
      success: true,
      user: userObject,
      aiPlan: {
        dailyCalories: aiPlan.dailyCalories,
        macros: aiPlan.macros,
        waterGlasses: aiPlan.waterGlasses,
        targetWeight: aiPlan.targetWeight,
        goalTitle: aiPlan.goalTitle,
        goalDescription: aiPlan.goalDescription
      }
    });
    
  } catch (error) {
    console.error('Onboarding completion error:', error);
    res.status(500).json({
      success: false,
      message: 'Ошибка завершения onboarding: ' + error.message
    });
  }
});

module.exports = router;
