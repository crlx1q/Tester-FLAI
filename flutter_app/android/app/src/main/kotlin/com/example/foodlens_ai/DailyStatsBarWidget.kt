package com.example.foodlens_ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.widget.Toast
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class DailyStatsBarWidget : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val pendingResult = goAsync()
            Thread {
                try {
                    super.onReceive(context, intent)
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
        for (appWidgetId in appWidgetIds) {
            try {
                showLoadingState(context, appWidgetManager, appWidgetId)
                fetchAndUpdateWidgetSync(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    companion object {
        private const val BASE_URL = "https://foodlensai.crlx1q.com/api"

        private fun showLoadingState(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_daily_stats_bar_v2)
                views.setTextViewText(R.id.tv_bar_calories, "...")
                views.setTextViewText(R.id.tv_bar_protein, "...")
                views.setTextViewText(R.id.tv_bar_fat, "...")
                views.setTextViewText(R.id.tv_bar_carbs, "...")
                views.setTextViewText(R.id.tv_bar_water, "...")
                setupClickIntent(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private fun setupClickIntent(context: Context, views: RemoteViews, appWidgetId: Int) {
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = QuickActionsWidget.ACTION_OPEN_APP
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 200 + appWidgetId, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_bar_root, pendingIntent)
        }

        fun fetchAndUpdateWidgetSync(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val token = QuickActionsWidget.getAuthToken(context)
            if (token == null) {
                try {
                    val views = RemoteViews(context.packageName, R.layout.widget_daily_stats_bar_v2)
                    views.setTextViewText(R.id.tv_bar_calories, "—")
                    views.setTextViewText(R.id.tv_bar_protein, "—")
                    views.setTextViewText(R.id.tv_bar_fat, "—")
                    views.setTextViewText(R.id.tv_bar_carbs, "—")
                    views.setTextViewText(R.id.tv_bar_water, "—")
                    setupClickIntent(context, views, appWidgetId)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                return
            }

            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val today = dateFormat.format(Date())

                var calories = 0
                var protein = 0
                var fat = 0
                var carbs = 0

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
                            calories = dataObj.optInt("totalCalories", 0)
                            val macros = dataObj.optJSONObject("consumedMacros")
                            if (macros != null) {
                                protein = macros.optDouble("protein", 0.0).toInt()
                                fat = macros.optDouble("fat", 0.0).toInt()
                                carbs = macros.optDouble("carbs", 0.0).toInt()
                            }
                        }
                    }
                }
                summaryConn.disconnect()

                var waterAmount = 0
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

                val views = RemoteViews(context.packageName, R.layout.widget_daily_stats_bar_v2)
                views.setTextViewText(R.id.tv_bar_calories, "$calories")
                views.setTextViewText(R.id.tv_bar_protein, "${protein}г")
                views.setTextViewText(R.id.tv_bar_fat, "${fat}г")
                views.setTextViewText(R.id.tv_bar_carbs, "${carbs}г")
                views.setTextViewText(R.id.tv_bar_water, "$waterAmount")

                setupClickIntent(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                val errorMsg = e.javaClass.simpleName
                val views = RemoteViews(context.packageName, R.layout.widget_daily_stats_bar_v2)
                views.setTextViewText(R.id.tv_bar_calories, "—")
                views.setTextViewText(R.id.tv_bar_protein, "—")
                views.setTextViewText(R.id.tv_bar_fat, "—")
                views.setTextViewText(R.id.tv_bar_carbs, "—")
                views.setTextViewText(R.id.tv_bar_water, "Ошибка")
                setupClickIntent(context, views, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, "Ошибка: $errorMsg", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
