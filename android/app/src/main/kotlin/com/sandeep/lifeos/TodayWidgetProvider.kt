package com.sandeep.lifeos

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * LifeOS · Today: today's to-dos, habits done, and this month's spend.
 *
 * Everything shown is worked out by the app (TodayWidgetSnapshot) and saved
 * here; this only lays it out. If what was saved is from an earlier day, the
 * widget says so and asks to be opened, rather than passing yesterday's list
 * off as today's. Tapping anywhere opens the app.
 */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, widgetData))
        }
    }

    private fun build(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        val now = Date()
        views.setTextViewText(
            R.id.widget_date,
            SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(now),
        )

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val savedDay = data.getString("today_day", null)
        val taskLines = listOf(R.id.widget_task_1, R.id.widget_task_2, R.id.widget_task_3)

        if (savedDay != today) {
            // Nothing saved yet, or it's a new day since the app last ran.
            views.setTextViewText(R.id.widget_tasks_heading, "")
            taskLines.forEach { views.setViewVisibility(it, View.GONE) }
            views.setViewVisibility(R.id.widget_stats, View.GONE)
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_message,
                if (savedDay == null) "Open LifeOS to see your day here."
                else "Tap to bring today up to date.",
            )
            return views
        }

        views.setViewVisibility(R.id.widget_stats, View.VISIBLE)
        val locked = data.getInt("today_locked", 0) == 1
        val left = data.getInt("today_tasks_left", 0)
        val total = data.getInt("today_tasks_total", 0)
        views.setTextViewText(
            R.id.widget_tasks_heading,
            when {
                total == 0 -> "No to-dos today"
                left == 0 -> "All $total to-dos done"
                else -> "$left of $total to-dos left"
            },
        )

        val titles = listOf("today_task_1", "today_task_2", "today_task_3")
            .map { data.getString(it, "") ?: "" }
        taskLines.forEachIndexed { i, viewId ->
            val title = titles[i]
            views.setViewVisibility(viewId, if (title.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(viewId, "○  $title")
        }

        // App lock on: counts only, nothing readable over someone's shoulder.
        val message = when {
            locked -> "App lock is on — open LifeOS to see details."
            total > 0 && left == 0 -> "Nothing left on the list."
            else -> ""
        }
        views.setViewVisibility(R.id.widget_message, if (message.isEmpty()) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.widget_message, message)

        views.setTextViewText(R.id.widget_spend, if (locked) "Locked" else data.getString("today_spend", "") ?: "")
        val habitsDone = data.getInt("today_habits_done", 0)
        val habitsTotal = data.getInt("today_habits_total", 0)
        views.setTextViewText(
            R.id.widget_habits,
            if (habitsTotal == 0) "None today" else "$habitsDone of $habitsTotal",
        )
        return views
    }
}
