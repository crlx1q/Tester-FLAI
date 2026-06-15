package com.example.foodlens_ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class DailyStatsSmallWidget : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE || action == ACTION_SMALL_ADD_WATER) {
            val pendingResult = goAsync()
            Thread {
                try {
                    super.onReceive(context, intent)
                    if (action == ACTION_SMALL_ADD_WATER) {
                        addWaterSync(context)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                } finally {
                    pendingResult.finish()
                }
            }.start()
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Runs on a background thread thanks to goAsync() in onReceive
        for (appWidgetId in appWidgetIds) {
            try {
                showLoadingState(context, appWidgetManager, appWidgetId)
                fetchAndUpdateWidgetSync(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val pendingResult = goAsync()
        Thread {
            try {
                showLoadingState(context, appWidgetManager, appWidgetId)
                fetchAndUpdateWidgetSync(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                pendingResult.finish()
            }
        }.start()
    }


    companion object {
        const val ACTION_SMALL_ADD_WATER = "com.example.foodlens_ai.ACTION_SMALL_ADD_WATER"
        private const val BASE_URL = "https://foodlensai.crlx1q.com/api"
        private const val WATER_STEP = 100

        private fun getMealReminder(foods: JSONArray?): String {
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            var hasBreakfast = false
            var hasLunch = false
            var hasDinner = false

            if (foods != null) {
                for (i in 0 until foods.length()) {
                    val food = foods.optJSONObject(i)
                    val mealType = food?.optString("mealType", "") ?: ""
                    if (mealType.equals("Завтрак", ignoreCase = true)) hasBreakfast = true
                    if (mealType.equals("Обед", ignoreCase = true)) hasLunch = true
                    if (mealType.equals("Ужин", ignoreCase = true)) hasDinner = true
                }
            }

            return when (hour) {
                in 6..10 -> if (!hasBreakfast) "Запиши завтрак! 🍳" else "Отлично! Ждём обед 🍲"
                in 11..15 -> if (!hasLunch) "Время обедать! 🍲" else "Отлично! Ждём ужин 🥗"
                in 16..22 -> if (!hasDinner) "Время ужина! 🥗" else "Норма выполнена! 🌙"
                else -> "Доброй ночи! 🌙"
            }
        }


        private fun getLayoutId(appWidgetManager: AppWidgetManager, appWidgetId: Int): Int {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            return if (minWidth > 200) {
                R.layout.widget_daily_stats_small_v2_wide
            } else {
                R.layout.widget_daily_stats_small_v2
            }
        }

        private fun showLoadingState(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val layoutId = getLayoutId(appWidgetManager, appWidgetId)
                val views = RemoteViews(context.packageName, layoutId)
                views.setTextViewText(R.id.tv_meal_reminder, "Обновление...")
                views.setTextViewText(R.id.tv_calories, "...")
                views.setTextViewText(R.id.tv_calories_target, "")
                views.setTextViewText(R.id.tv_water, "...")
                views.setTextViewText(R.id.tv_water_target, "")
                views.setViewVisibility(R.id.progress_calories_full, android.view.View.GONE)
                views.setViewVisibility(R.id.progress_calories, android.view.View.VISIBLE)
                views.setProgressBar(R.id.progress_calories, 100, 0, false)
                views.setProgressBar(R.id.progress_water, 100, 0, false)

                setupClickIntents(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private fun setupClickIntents(context: Context, views: RemoteViews, appWidgetId: Int) {
            val addWaterIntent = Intent(context, DailyStatsSmallWidget::class.java).apply {
                action = ACTION_SMALL_ADD_WATER
            }
            val addWaterPendingIntent = PendingIntent.getBroadcast(
                context, 100 + appWidgetId, addWaterIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_small_add_water, addWaterPendingIntent)

            val cameraIntent = Intent(context, MainActivity::class.java).apply {
                action = QuickActionsWidget.ACTION_OPEN_CAMERA
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = Uri.parse("foodlens://camera")
            }
            val cameraPendingIntent = PendingIntent.getActivity(
                context, 101 + appWidgetId, cameraIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_small_camera, cameraPendingIntent)

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = QuickActionsWidget.ACTION_OPEN_APP
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 102 + appWidgetId, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_small_root, openAppPendingIntent)
        }

        private fun fetchAndUpdateWidgetSync(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val token = QuickActionsWidget.getAuthToken(context)
            val layoutId = getLayoutId(appWidgetManager, appWidgetId)
            if (token == null) {
                try {
                    val views = RemoteViews(context.packageName, layoutId)
                    views.setTextViewText(R.id.tv_meal_reminder, "Войдите в аккаунт")
                    views.setTextViewText(R.id.tv_calories, "—")
                    views.setTextViewText(R.id.tv_calories_target, "")
                    views.setTextViewText(R.id.tv_water, "—")
                    views.setTextViewText(R.id.tv_water_target, "")
                    views.setViewVisibility(R.id.progress_calories_full, android.view.View.GONE)
                    views.setViewVisibility(R.id.progress_calories, android.view.View.VISIBLE)
                    views.setProgressBar(R.id.progress_calories, 100, 0, false)
                    views.setProgressBar(R.id.progress_water, 100, 0, false)
                    setupClickIntents(context, views, appWidgetId)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                return
            }

            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val today = dateFormat.format(Date())

                var totalCalories = 0
                var targetCalories = 2000
                var foodsArray: JSONArray? = null

                val summaryUrl = URL("$BASE_URL/food/daily-summary?date=$today")
                val summaryConn = summaryUrl.openConnection() as HttpURLConnection
                summaryConn.requestMethod = "GET"
                summaryConn.setRequestProperty("Authorization", "Bearer $token")
                summaryConn.setRequestProperty("Content-Type", "application/json")
                summaryConn.setRequestProperty("User-Agent", "FoodLensWidget/1.0")
                summaryConn.connectTimeout = 15000
                summaryConn.readTimeout = 15000

                if (summaryConn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(summaryConn.inputStream))
                    val response = reader.readText()
                    reader.close()
                    val json = JSONObject(response)
                    if (json.optBoolean("success", false)) {
                        val dataObj = json.optJSONObject("data")
                        if (dataObj != null) {
                            totalCalories = dataObj.optInt("totalCalories", 0)
                            targetCalories = dataObj.optInt("targetCalories", 2000)
                            foodsArray = dataObj.optJSONArray("foods")
                        }
                    }
                }
                summaryConn.disconnect()

                var waterAmount = 0
                var waterTarget = 1700
                val waterUrl = URL("$BASE_URL/food/water/$today")
                val waterConn = waterUrl.openConnection() as HttpURLConnection
                waterConn.requestMethod = "GET"
                waterConn.setRequestProperty("Authorization", "Bearer $token")
                waterConn.setRequestProperty("Content-Type", "application/json")
                waterConn.setRequestProperty("User-Agent", "FoodLensWidget/1.0")
                waterConn.connectTimeout = 15000
                waterConn.readTimeout = 15000

                if (waterConn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(waterConn.inputStream))
                    val response = reader.readText()
                    reader.close()
                    val json = JSONObject(response)
                    if (json.optBoolean("success", false)) {
                        val waterIntake = json.optJSONObject("waterIntake")
                        waterAmount = waterIntake?.optInt("amount", 0) ?: 0
                    }
                }
                waterConn.disconnect()

                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val savedTarget = prefs.getLong("flutter.water_target", 0L)
                    if (savedTarget > 0) waterTarget = savedTarget.toInt()
                } catch (e: Exception) { /* ignore */ }

                val calorieProgress = if (targetCalories > 0) {
                    ((totalCalories.toFloat() / targetCalories) * 100).toInt().coerceIn(0, 100)
                } else 0

                val waterProgress = if (waterTarget > 0) {
                    ((waterAmount.toFloat() / waterTarget) * 100).toInt().coerceIn(0, 100)
                } else 0

                val views = RemoteViews(context.packageName, layoutId)
                views.setTextViewText(R.id.tv_meal_reminder, getMealReminder(foodsArray))
                views.setTextViewText(R.id.tv_calories, "$totalCalories")
                views.setTextViewText(R.id.tv_calories_target, "/$targetCalories ккал")
                views.setTextViewText(R.id.tv_water, "$waterAmount")
                views.setTextViewText(R.id.tv_water_target, "/$waterTarget мл")
                
                if (calorieProgress >= 100) {
                    views.setViewVisibility(R.id.progress_calories, android.view.View.GONE)
                    views.setViewVisibility(R.id.progress_calories_full, android.view.View.VISIBLE)
                    views.setProgressBar(R.id.progress_calories_full, 100, calorieProgress, false)
                } else {
                    views.setViewVisibility(R.id.progress_calories_full, android.view.View.GONE)
                    views.setViewVisibility(R.id.progress_calories, android.view.View.VISIBLE)
                    views.setProgressBar(R.id.progress_calories, 100, calorieProgress, false)
                }

                views.setProgressBar(R.id.progress_water, 100, waterProgress, false)

                setupClickIntents(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                e.printStackTrace()
                val errorViews = RemoteViews(context.packageName, layoutId)
                setupClickIntents(context, errorViews, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, errorViews)
            }
        }

        private fun addWaterSync(context: Context) {
            val token = QuickActionsWidget.getAuthToken(context)
            if (token == null) {
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, "Войдите в приложение", Toast.LENGTH_SHORT).show()
                }
                return
            }

            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val today = dateFormat.format(Date())

                val getUrl = URL("$BASE_URL/food/water/$today")
                val getConn = getUrl.openConnection() as HttpURLConnection
                getConn.requestMethod = "GET"
                getConn.setRequestProperty("Authorization", "Bearer $token")
                getConn.setRequestProperty("Content-Type", "application/json")
                getConn.setRequestProperty("User-Agent", "FoodLensWidget/1.0")
                getConn.connectTimeout = 15000
                getConn.readTimeout = 15000

                var currentAmount = 0
                if (getConn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(getConn.inputStream))
                    val response = reader.readText()
                    reader.close()
                    val json = JSONObject(response)
                    if (json.optBoolean("success", false)) {
                        val waterIntake = json.optJSONObject("waterIntake")
                        currentAmount = waterIntake?.optInt("amount", 0) ?: 0
                    }
                }
                getConn.disconnect()

                val newAmount = currentAmount + WATER_STEP
                val postUrl = URL("$BASE_URL/food/water")
                val postConn = postUrl.openConnection() as HttpURLConnection
                postConn.requestMethod = "POST"
                postConn.setRequestProperty("Authorization", "Bearer $token")
                postConn.setRequestProperty("Content-Type", "application/json")
                postConn.setRequestProperty("User-Agent", "FoodLensWidget/1.0")
                postConn.connectTimeout = 15000
                postConn.readTimeout = 15000
                postConn.doOutput = true

                val body = JSONObject().apply {
                    put("date", today)
                    put("amount", newAmount)
                }

                val writer = OutputStreamWriter(postConn.outputStream)
                writer.write(body.toString())
                writer.flush()
                writer.close()

                val success = postConn.responseCode == 200
                postConn.disconnect()

                Handler(Looper.getMainLooper()).post {
                    if (success) {
                        Toast.makeText(context, "+${WATER_STEP} мл 💧 ($newAmount мл)", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(context, "Ошибка добавления воды", Toast.LENGTH_SHORT).show()
                    }
                }
                
                // Fetch the newly updated data to reflect accurately on widgets
                if (success) {
                    refreshAllWidgetsSync(context)
                }
            } catch (e: Exception) {
                val errorMsg = e.javaClass.simpleName
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, "Ошибка: $errorMsg", Toast.LENGTH_LONG).show()
                }
            }
        }

        private fun refreshAllWidgetsSync(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val smallIds = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyStatsSmallWidget::class.java))
                for (id in smallIds) {
                    fetchAndUpdateWidgetSync(context, appWidgetManager, id)
                }

                val barIds = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyStatsBarWidget::class.java))
                if (barIds.isNotEmpty()) {
                    val barIntent = Intent(context, DailyStatsBarWidget::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, barIds)
                    }
                    context.sendBroadcast(barIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
