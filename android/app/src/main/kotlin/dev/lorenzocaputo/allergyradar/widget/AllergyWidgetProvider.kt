package dev.lorenzocaputo.allergyradar.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.graphics.Typeface
import android.view.View
import android.widget.RemoteViews
import dev.lorenzocaputo.allergyradar.R
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Widget «La tua giornata»: livello del giorno e allergeni seguiti.
 * Legge i dati che l'app scrive in SharedPreferences (chiave flutter.widget_data),
 * quindi si aggiorna anche con l'app chiusa, dopo il controllo in background.
 */
class AllergyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.widget_data"

        // Colori del testo per livello 0–4, come nella scala dell'app.
        private val LEVEL_LIGHT = intArrayOf(0xFF5C6661.toInt(), 0xFF76580A.toInt(), 0xFF94470A.toInt(), 0xFFA63A1B.toInt(), 0xFF7A2338.toInt())
        private val LEVEL_DARK = intArrayOf(0xFF9AA49E.toInt(), 0xFFEBCB6E.toInt(), 0xFFF0A860.toInt(), 0xFFF2825E.toInt(), 0xFFF08CA2.toInt())
        private val ROWS = intArrayOf(R.id.widget_row1, R.id.widget_row2, R.id.widget_row3)

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AllergyWidgetProvider::class.java))
            ids.forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.allergy_widget)
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val colors = if (night) LEVEL_DARK else LEVEL_LIGHT

            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            if (raw == null) {
                views.setTextViewText(R.id.widget_place, context.getString(R.string.app_name))
                views.setTextViewText(R.id.widget_level, context.getString(R.string.widget_empty))
                ROWS.forEach { views.setViewVisibility(it, View.GONE) }
                views.setTextViewText(R.id.widget_updated, "")
            } else {
                val data = JSONObject(raw)
                views.setTextViewText(R.id.widget_place, data.optString("place"))
                views.setTextViewText(R.id.widget_level, data.optString("levelLabel"))
                views.setTextColor(R.id.widget_level, colors[data.optInt("level").coerceIn(0, 4)])
                val allergens = data.optJSONArray("allergens")
                ROWS.forEachIndexed { i, rowId ->
                    val item = allergens?.optJSONObject(i)
                    if (item == null) {
                        views.setViewVisibility(rowId, View.GONE)
                    } else {
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(rowId, row(item, colors))
                    }
                }
                views.setTextViewText(R.id.widget_updated, updatedAt(data.optString("updated")))
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pending = PendingIntent.getActivity(
                    context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }
            manager.updateAppWidget(id, views)
        }

        private fun row(item: JSONObject, colors: IntArray): CharSequence {
            val name = item.optString("name")
            val label = item.optString("levelLabel") + if (item.optBoolean("estimate")) " *" else ""
            val text = SpannableStringBuilder("$name  $label")
            val start = name.length + 2
            text.setSpan(ForegroundColorSpan(colors[item.optInt("level").coerceIn(0, 4)]), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            text.setSpan(StyleSpan(Typeface.BOLD), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            return text
        }

        private fun updatedAt(iso: String): String = try {
            val time = try {
                OffsetDateTime.parse(iso).toLocalTime()
            } catch (_: Exception) {
                LocalDateTime.parse(iso).toLocalTime()
            }
            "Aggiornato alle " + time.format(DateTimeFormatter.ofPattern("HH:mm"))
        } catch (_: Exception) {
            ""
        }
    }
}
