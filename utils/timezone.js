/**
 * Утилита для работы с часовым поясом приложения
 * ВАЖНО: process.env.TZ установлен в Asia/Almaty в server.js
 * Поэтому new Date() везде возвращает время в Almaty!
 */

// Получаем timezone из .env (по умолчанию Asia/Almaty - GMT+5)
const TIMEZONE = process.env.TIMEZONE || 'Asia/Almaty';

/**
 * Получить текущую дату/время (теперь просто new Date(), т.к. TZ установлен глобально)
 * @returns {Date} Текущая дата/время
 */
function getCurrentDate() {
  return new Date(); // Просто! Никаких конвертаций!
}

/**
 * Получить начало дня (00:00:00) для заданной даты
 * @param {Date} date - Дата для обработки
 * @returns {Date} Начало дня
 */
function getLocalDay(date) {
  const dayStart = new Date(date);
  dayStart.setHours(0, 0, 0, 0);
  return dayStart;
}

/**
 * Получить сегодняшний день (00:00:00)
 * @returns {Date} Начало текущего дня
 */
function getTodayStart() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return today;
}

/**
 * Проверить, совпадает ли дата с сегодняшним днем в часовом поясе приложения
 * @param {Date} date - Дата для проверки
 * @returns {boolean} true если дата совпадает с сегодня
 */
function isToday(date) {
  const today = getTodayStart();
  const checkDay = getLocalDay(date);
  return checkDay.getTime() === today.getTime();
}

/**
 * Получить разницу в днях между двумя датами
 * @param {Date} date1 - Первая дата
 * @param {Date} date2 - Вторая дата
 * @returns {number} Разница в днях
 */
function getDaysDifference(date1, date2) {
  const day1 = getLocalDay(date1);
  const day2 = getLocalDay(date2);
  return Math.floor((day1 - day2) / (1000 * 60 * 60 * 24));
}

/**
 * Получить дату в формате YYYY-MM-DD
 * @param {Date} date - Дата
 * @returns {string} Дата в формате YYYY-MM-DD
 */
function getDateString(date) {
  // Просто! Date уже в нужном часовом поясе
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

module.exports = {
  TIMEZONE,
  getCurrentDate,
  getLocalDay,
  getTodayStart,
  isToday,
  getDaysDifference,
  getDateString
};

