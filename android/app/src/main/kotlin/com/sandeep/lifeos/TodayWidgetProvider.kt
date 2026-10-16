package com.sandeep.lifeos

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
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
class TodayWidgetProvider : AppWidgetProvider() {
    companion object {
        /** Where MainActivity's `com.sandeep.lifeos/widget` channel saves the snapshot. */
        private const val PREFS = "lifeos_today_widget"

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** Redraws every placed copy of the widget from what's saved. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
            for (id in ids) manager.updateAppWidget(id, build(context, prefs(context)))
        }

        private fun build(context: Context, data: SharedPreferences): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            val launch = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launch)
            return fill(views, data)
        }

        private fun fill(views: RemoteViews, data: SharedPreferences): RemoteViews {
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
                    // The list is worked out by the app, so a new day's
                    // can't appear until the app has run since midnight.
                    if (savedDay == null) "Open LifeOS to see your day here."
                    else "A new day — open LifeOS to load today's list.",
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

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, prefs(context)))
        }
    }
}
