package com.itsash.moon_locator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.format.DateFormat
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widget: tonight's moon. All astronomy is computed in Dart (lib/widget_sync.dart);
 * this class only reads the JSON the app stored in SharedPreferences and picks today's entry.
 */
class MoonWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) manager.updateAppWidget(id, views)
    }

    companion object {
        private const val PREFS = "moon_widget"
        private const val KEY = "data"

        /** Saves the JSON from Dart and refreshes every widget instance. */
        fun store(context: Context, json: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val old = prefs.getString(KEY, null)
            // A phases-only update (no location yet) must not erase rise/set from a located one.
            val incomingLocated = runCatching { JSONObject(json).optBoolean("located") }.getOrDefault(false)
            val oldLocated = old != null && runCatching { JSONObject(old).optBoolean("located") }.getOrDefault(false)
            if (!incomingLocated && oldLocated) return
            prefs.edit().putString(KEY, json).apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MoonWidget::class.java))
            if (ids.isEmpty()) return
            val views = build(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent()
            return PendingIntent.getActivity(
                context, 31, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_moon)
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))

            val data = runCatching {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
                    ?.let { JSONObject(it) }
            }.getOrNull()

            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            var entry: JSONObject? = null
            val days = data?.optJSONArray("days")
            if (days != null) {
                for (i in 0 until days.length()) {
                    val d = days.optJSONObject(i)
                    if (d != null && d.optString("d") == today) {
                        entry = d
                        break
                    }
                }
            }

            if (data == null || entry == null) {
                views.setViewVisibility(R.id.widget_content, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
                return views
            }
            views.setViewVisibility(R.id.widget_content, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)

            val timeFmt = DateFormat.getTimeFormat(context)
            fun time(key: String): String =
                if (entry.has(key)) timeFmt.format(Date(entry.getLong(key))) else "--"

            val phase = entry.optDouble("p", 0.0)
            val illum = entry.optInt("i", 0)
            views.setImageViewBitmap(R.id.widget_moon, moonBitmap(phase, illum / 100.0))
            views.setTextViewText(R.id.widget_phase, entry.optString("n"))
            views.setTextViewText(R.id.widget_illum, context.getString(R.string.widget_illum, illum))

            if (data.optBoolean("located")) {
                views.setTextViewText(
                    R.id.widget_times,
                    context.getString(R.string.widget_rise_set, time("r"), time("s")),
                )
            } else {
                views.setTextViewText(R.id.widget_times, context.getString(R.string.widget_no_location))
            }

            val dateFmt = SimpleDateFormat(DateFormat.getBestDateTimePattern(Locale.getDefault(), "d MMM"), Locale.getDefault())
            val now = System.currentTimeMillis()
            fun next(arr: JSONArray?): String {
                if (arr == null) return "--"
                for (i in 0 until arr.length()) {
                    val t = arr.optLong(i)
                    if (t > now) return dateFmt.format(Date(t))
                }
                return "--"
            }
            views.setTextViewText(
                R.id.widget_next,
                context.getString(R.string.widget_next, next(data.optJSONArray("full")), next(data.optJSONArray("new"))),
            )
            return views
        }

        /** Draws the lit part of the moon as a flat disc (waxing = lit on the right, northern view). */
        private fun moonBitmap(phase: Double, illum: Double): Bitmap {
            val size = 160
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            val dark = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#2A3358") }
            val lit = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#F4EFD8") }
            val r = size / 2f
            val disc = RectF(0f, 0f, size.toFloat(), size.toFloat())
            c.drawCircle(r, r, r, dark)
            val waxing = phase < 0.5
            // Lit half of the disc (right half when waxing, left when waning).
            c.drawArc(disc, if (waxing) -90f else 90f, 180f, true, lit)
            // Terminator ellipse: dark over the lit half for a crescent, lit over the dark half for gibbous.
            val w = (r * Math.abs(1.0 - 2.0 * illum)).toFloat()
            if (w > 0.5f) {
                val ellipse = RectF(r - w, 0f, r + w, size.toFloat())
                c.drawOval(ellipse, if (illum < 0.5) dark else lit)
            }
            return bmp
        }
    }
}
