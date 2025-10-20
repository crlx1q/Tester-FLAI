# Используем официальный Node.js образ
FROM node:18-alpine

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем package.json и package-lock.json
COPY package*.json ./

# Устанавливаем зависимости
RUN npm ci --only=production

# Копируем исходный код
COPY . .

# Создаем необходимые директории
RUN mkdir -p uploads data apk

# Открываем порт
EXPOSE 8000

# Указываем команду для запуска
CMD ["npm", "start"]
