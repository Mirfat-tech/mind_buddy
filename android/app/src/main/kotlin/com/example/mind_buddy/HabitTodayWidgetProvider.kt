package com.example.mind_buddy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class HabitTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val chipIds = intArrayOf(
            R.id.habit_chip_1,
            R.id.habit_chip_2,
            R.id.habit_chip_3,
            R.id.habit_chip_4,
            R.id.habit_chip_5,
            R.id.habit_chip_6
        )

        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.habit_today_widget)
            val title = widgetData.getString("habits_widget_title", "Habits") ?: "Habits"
            val itemsJson = widgetData.getString("habits_widget_items_json", "[]") ?: "[]"
            val moreCount = widgetData.getInt("habits_widget_more_count", 0)
            val errorMessage = widgetData.getString("habits_widget_error", null)
            val textColor = widgetData.getInt("habits_theme_text", 0xFF202235.toInt())
            val mutedColor = widgetData.getInt("habits_theme_muted", 0xFF4D5272.toInt())
            val accentColor = widgetData.getInt("habits_theme_accent", 0xFF5E7BFF.toInt())
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 176)
            val maxRows = when {
                minHeightDp < 170 -> 3
                minHeightDp < 250 -> 4
                else -> 6
            }

            views.setTextViewText(R.id.habit_widget_title, title)
            views.setTextColor(R.id.habit_widget_title, textColor)
            views.setTextColor(R.id.habit_widget_view_all, accentColor)

            val rootPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("brainbubble://widget/habits")
            )
            views.setOnClickPendingIntent(R.id.habit_widget_view_all, rootPendingIntent)

            val parsedItems = parseItems(itemsJson)
            val totalPotential = parsedItems.size + moreCount
            val hasOverflow = totalPotential > maxRows
            val displayHabitCount = if (hasOverflow) {
                (maxRows - 1).coerceAtLeast(0)
            } else {
                minOf(parsedItems.size, maxRows)
            }
            chipIds.forEachIndexed { idx, viewId ->
                if (idx < parsedItems.size && idx < displayHabitCount && idx < chipIds.size) {
                    val item = parsedItems[idx]
                    views.setViewVisibility(viewId, View.VISIBLE)
                    views.setTextViewText(viewId, item.name)
                    views.setTextColor(viewId, if (item.done) accentColor else textColor)
                    views.setInt(
                        viewId,
                        "setBackgroundResource",
                        if (item.done) R.drawable.habit_widget_chip_done else R.drawable.habit_widget_chip_incomplete
                    )
                    val action = "homewidget://toggle?habit_id=${Uri.encode(item.id)}&habit_name=${Uri.encode(item.name)}"
                    val habitPendingIntent = backgroundToggleIntent(
                        context = context,
                        uri = Uri.parse(action),
                        requestCode = 2000 + idx
                    )
                    views.setOnClickPendingIntent(viewId, habitPendingIntent)
                } else {
                    views.setViewVisibility(viewId, View.GONE)
                }
            }

            val hiddenFromWidget = if (parsedItems.size > displayHabitCount) {
                parsedItems.size - displayHabitCount
            } else {
                0
            }
            val effectiveMoreCount = moreCount + hiddenFromWidget
            if (effectiveMoreCount > 0) {
                views.setViewVisibility(R.id.habit_chip_more, View.VISIBLE)
                views.setTextViewText(R.id.habit_chip_more, "+$effectiveMoreCount more")
                views.setTextColor(R.id.habit_chip_more, mutedColor)
                views.setOnClickPendingIntent(R.id.habit_chip_more, rootPendingIntent)
            } else {
                views.setViewVisibility(R.id.habit_chip_more, View.GONE)
            }

            if (!errorMessage.isNullOrBlank() &&
                effectiveMoreCount == 0 &&
                displayHabitCount < maxRows) {
                views.setViewVisibility(R.id.habit_widget_error, View.VISIBLE)
                views.setTextViewText(R.id.habit_widget_error, errorMessage)
            } else {
                views.setViewVisibility(R.id.habit_widget_error, View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun backgroundToggleIntent(
        context: Context,
        uri: Uri,
        requestCode: Int
    ): PendingIntent {
        val intent = android.content.Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
            action = "es.antonborri.home_widget.action.BACKGROUND"
            data = uri
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (android.os.Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun parseItems(rawJson: String): List<HabitItem> {
        return try {
            val arr = JSONArray(rawJson)
            val out = mutableListOf<HabitItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val id = obj.optString("id", "").trim()
                val name = obj.optString("name", "").trim()
                if (id.isEmpty() || name.isEmpty()) continue
                val done = obj.optBoolean("done", false)
                out.add(HabitItem(id = id, name = name, done = done))
            }
            out
        } catch (_: Throwable) {
            emptyList()
        }
    }

    data class HabitItem(
        val id: String,
        val name: String,
        val done: Boolean
    )

    companion object {
        fun forceUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, HabitTodayWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(thisWidget)
            if (ids.isNotEmpty()) {
                manager.notifyAppWidgetViewDataChanged(ids, R.id.habit_widget_root)
            }
        }
    }
}
