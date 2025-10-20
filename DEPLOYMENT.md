# FoodLens AI - Koyeb Deployment Guide

## 🚀 Деплой на Koyeb с MongoDB Atlas

### 1. Предварительная подготовка

Перед деплоем убедитесь, что у вас есть:
- Аккаунт на [Koyeb](https://www.koyeb.com)
- Настроенная база данных MongoDB Atlas
- API ключ от Google Gemini

### 2. Создание секретов в Koyeb

Перейдите в [Koyeb Secrets](https://app.koyeb.com/secrets) и создайте следующие секреты:

#### Обязательные секреты:

| Название секрета | Описание | Пример значения |
|------------------|----------|-----------------|
| `MONGODB_USERNAME` | Имя пользователя MongoDB | `ilemarussplay_db_user` |
| `MONGODB_PASSWORD` | Пароль MongoDB | `i5yRonn3lPanyv4X` |
| `MONGODB_URI` | Полная строка подключения | `mongodb+srv://{{ secret.MONGODB_USERNAME }}:{{ secret.MONGODB_PASSWORD }}@cluster0.1lfp0sx.mongodb.net/foodlens?retryWrites=true&w=majority&appName=Cluster0` |
| `JWT_SECRET` | Секретный ключ для JWT | `your-super-secret-jwt-key-256-bit` |
| `AI_API_KEY` | API ключ Google Gemini | `AIzaSy...` |
| `AI_PROVIDER` | Провайдер AI | `gemini` |
| `AI_API_URL` | URL API Gemini | `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent` |
| `AI_MODEL` | Модель AI | `gemini-2.0-flash-exp` |
| `ADMIN_PASSWORD` | Пароль админки | `your-secure-admin-password` |

### 3. Способы деплоя

#### Способ 1: Через GitHub (Рекомендуется)

1. Загрузите код в GitHub репозиторий
2. В Koyeb создайте новый App
3. Выберите "Deploy from GitHub"
4. Выберите ваш репозиторий и папку `server`
5. Настройте Environment Variables (см. секцию 4)

#### Способ 2: Через Docker

1. Соберите Docker образ:
```bash
cd server
docker build -t foodlens-ai .
```

2. Загрузите в Docker registry (Docker Hub, GitHub Container Registry, etc.)

3. В Koyeb создайте App с Docker образом

#### Способ 3: Через CLI

```bash
# Установите Koyeb CLI
npm install -g @koyeb/cli

# Авторизуйтесь
koyeb auth login

# Деплой из папки server
cd server
koyeb app init foodlens-ai
koyeb service create foodlens-ai-server \
  --app foodlens-ai \
  --git github.com/your-username/your-repo \
  --git-branch main \
  --git-workdir server \
  --ports 8000:http \
  --env NODE_ENV=production \
  --env PORT=8000 \
  --env MONGODB_URI="{{ secret.MONGODB_URI }}" \
  --env JWT_SECRET="{{ secret.JWT_SECRET }}" \
  --env AI_API_KEY="{{ secret.AI_API_KEY }}" \
  --env AI_PROVIDER="{{ secret.AI_PROVIDER }}" \
  --env AI_API_URL="{{ secret.AI_API_URL }}" \
  --env AI_MODEL="{{ secret.AI_MODEL }}" \
  --env ADMIN_PASSWORD="{{ secret.ADMIN_PASSWORD }}"
```

### 4. Настройка Environment Variables

В настройках вашего Koyeb App добавьте следующие переменные среды:

```env
NODE_ENV=production
PORT=8000
MONGODB_URI={{ secret.MONGODB_URI }}
JWT_SECRET={{ secret.JWT_SECRET }}
AI_API_KEY={{ secret.AI_API_KEY }}
AI_PROVIDER={{ secret.AI_PROVIDER }}
AI_API_URL={{ secret.AI_API_URL }}
AI_MODEL={{ secret.AI_MODEL }}
ADMIN_PASSWORD={{ secret.ADMIN_PASSWORD }}
```

### 5. Настройки приложения

- **Runtime**: Node.js 18
- **Build Command**: `npm install`
- **Start Command**: `npm start`
- **Port**: 8000
- **Health Check**: `/api/health`
- **Region**: Frankfurt (fra) - ближайший к России
- **Instance Type**: Nano (для начала)

### 6. Особенности развертывания

#### Автоскейлинг
Koyeb автоматически масштабирует ваше приложение в зависимости от нагрузки.

#### Мониторинг
- Логи доступны в реальном времени в панели Koyeb
- Метрики производительности отслеживаются автоматически

#### SSL/TLS
- Koyeb автоматически предоставляет SSL сертификат
- HTTPS включен по умолчанию

### 7. После деплоя

1. **Проверьте статус**: `https://your-app.koyeb.app/api/health`

2. **Обновите Flutter приложение**: Измените API endpoint в Flutter коде на новый URL

3. **Тестирование**: Проверьте все функции через API

### 8. Возможные проблемы и решения

#### Проблема: Не работает подключение к MongoDB
**Решение**: 
- Проверьте правильность MONGODB_URI
- Убедитесь, что IP Koyeb добавлен в whitelist MongoDB Atlas
- Для MongoDB Atlas используйте: "Allow access from anywhere" (0.0.0.0/0)

#### Проблема: AI не отвечает
**Решение**:
- Проверьте правильность AI_API_KEY
- Убедитесь, что Gemini API включен в Google Cloud Console
- Проверьте квоты API

#### Проблема: Большие изображения
**Решение**:
- Приложение автоматически сжимает изображения до оптимального размера
- MongoDB лимит документа 16MB учтен в коде

### 9. Масштабирование

При росте нагрузки:
1. Увеличьте instance type в Koyeb
2. Настройте автоскейлинг
3. Рассмотрите использование CDN для изображений
4. Оптимизируйте запросы к MongoDB

### 10. Мониторинг производительности

- **Koyeb Dashboard**: Основные метрики
- **MongoDB Atlas**: Производительность БД
- **Logs**: `koyeb service logs foodlens-ai-server`

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи в Koyeb Dashboard
2. Убедитесь, что все секреты настроены правильно
3. Проверьте подключение к MongoDB Atlas
4. Проверьте работу API через Postman или curl

---

## 🎉 Готово!

Ваше приложение FoodLens AI теперь работает на современной облачной платформе с MongoDB Atlas!

**Преимущества:**
- ✅ Автоматическое масштабирование
- ✅ Глобальная CDN
- ✅ SSL из коробки
- ✅ Мониторинг и логи
- ✅ Надежное хранение в MongoDB Atlas
- ✅ Сжатие изображений для экономии места
