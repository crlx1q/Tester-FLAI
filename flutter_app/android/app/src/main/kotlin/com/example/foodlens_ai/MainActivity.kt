package com.example.foodlens_ai

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.foodlens.speech"
    private val SPEECH_REQUEST_CODE = 100
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    pendingResult = result
                    startSpeechRecognition()
                }
                "isAvailable" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.foodlens.widget").setMethodCallHandler { call, result ->
            if (call.method == "refreshWidgets") {
                refreshAllWidgets()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun refreshAllWidgets() {
        val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
        
        // Small Widget
        val smallIds = appWidgetManager.getAppWidgetIds(android.content.ComponentName(this, DailyStatsSmallWidget::class.java))
        if (smallIds.isNotEmpty()) {
            val intent = Intent(this, DailyStatsSmallWidget::class.java).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, smallIds)
            }
            sendBroadcast(intent)
        }

        // Bar Widget
        val barIds = appWidgetManager.getAppWidgetIds(android.content.ComponentName(this, DailyStatsBarWidget::class.java))
        if (barIds.isNotEmpty()) {
            val intent = Intent(this, DailyStatsBarWidget::class.java).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, barIds)
            }
            sendBroadcast(intent)
        }

        // Quick Actions Widget
        val quickIds = appWidgetManager.getAppWidgetIds(android.content.ComponentName(this, QuickActionsWidget::class.java))
        if (quickIds.isNotEmpty()) {
            val intent = Intent(this, QuickActionsWidget::class.java).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, quickIds)
            }
            sendBroadcast(intent)
        }
    }

    private fun startSpeechRecognition() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ru-RU")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Скажите название блюда")
        }
        
        try {
            startActivityForResult(intent, SPEECH_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult?.error("SPEECH_ERROR", "Распознавание речи недоступно", null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SPEECH_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = results?.get(0) ?: ""
                pendingResult?.success(spokenText)
            } else {
                pendingResult?.success("")
            }
            pendingResult = null
        }
    }
}
