package com.example.foodlens_ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
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
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class QuickActionsWidget : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE || action == ACTION_ADD_WATER) {
            val pendingResult = goAsync()
            Thread {
                try {
                    super.onReceive(context, intent)
                    if (action == ACTION_ADD_WATER) {
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
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_quick_actions_v2)

                val addWaterIntent = Intent(context, QuickActionsWidget::class.java).apply {
                    action = ACTION_ADD_WATER
                }
                val addWaterPendingIntent = PendingIntent.getBroadcast(
                    context, 0, addWaterIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_add_water, addWaterPendingIntent)

                val cameraIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_CAMERA
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    data = Uri.parse("foodlens://camera")
                }
                val cameraPendingIntent = PendingIntent.getActivity(
                    context, 1, cameraIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_camera, cameraPendingIntent)

                val openAppIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_APP
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val openAppPendingIntent = PendingIntent.getActivity(
                    context, 2, openAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_open_app, openAppPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    companion object {
        const val ACTION_ADD_WATER = "com.example.foodlens_ai.ACTION_ADD_WATER"
        const val ACTION_OPEN_CAMERA = "com.example.foodlens_ai.ACTION_OPEN_CAMERA"
        const val ACTION_OPEN_APP = "com.example.foodlens_ai.ACTION_OPEN_APP"
        private const val BASE_URL = "https://foodlensai.crlx1q.com/api"
        private const val WATER_STEP = 100

        fun getAuthToken(context: Context): String? {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.getString("flutter.auth_token", null)
            } catch (e: Exception) {
                null
            }
        }

        private fun addWaterSync(context: Context) {
            val token = getAuthToken(context)
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
                        Toast.makeText(context, "+${WATER_STEP} мл 💧 (${newAmount} мл)", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(context, "Ошибка добавления воды", Toast.LENGTH_SHORT).show()
                    }
                }
                
                if (success) {
                    updateAllDailyStatsWidgetsSync(context)
                }
            } catch (e: Exception) {
                val errorMsg = e.javaClass.simpleName
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, "Ошибка: $errorMsg", Toast.LENGTH_LONG).show()
                }
            }
        }

        private fun updateAllDailyStatsWidgetsSync(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                
                val smallWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, DailyStatsSmallWidget::class.java)
                )
                if (smallWidgetIds.isNotEmpty()) {
                    val smallIntent = Intent(context, DailyStatsSmallWidget::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallWidgetIds)
                    }
                    context.sendBroadcast(smallIntent)
                }

                val barWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, DailyStatsBarWidget::class.java)
                )
                if (barWidgetIds.isNotEmpty()) {
                    val barIntent = Intent(context, DailyStatsBarWidget::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, barWidgetIds)
                    }
                    context.sendBroadcast(barIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
