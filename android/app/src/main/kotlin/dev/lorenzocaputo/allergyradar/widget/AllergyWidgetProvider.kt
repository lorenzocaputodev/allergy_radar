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
import android.text.style.RelativeSizeSpan
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
 * Widget minimale: luogo e ora in alto, livello del giorno con barra a 4 segmenti, poi gli allergeni seguiti.
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

        // Colori per livello 0–4, come nella scala dell'app: testo e riempimento dei segmenti.
        private val TEXT_LIGHT = intArrayOf(0xFF5C6661.toInt(), 0xFF76580A.toInt(), 0xFF94470A.toInt(), 0xFFA63A1B.toInt(), 0xFF7A2338.toInt())
        private val TEXT_DARK = intArrayOf(0xFF9AA49E.toInt(), 0xFFEBCB6E.toInt(), 0xFFF0A860.toInt(), 0xFFF2825E.toInt(), 0xFFF08CA2.toInt())
        private val FILL_LIGHT = intArrayOf(0xFFE4E1D7.toInt(), 0xFFEFD27F.toInt(), 0xFFE59A48.toInt(), 0xFFC4502B.toInt(), 0xFF7A2338.toInt())
        private val FILL_DARK = intArrayOf(0xFF2C3632.toInt(), 0xFFE3C46E.toInt(), 0xFFE0913F.toInt(), 0xFFD0613A.toInt(), 0xFFB23A55.toInt())
        private val ROWS = intArrayOf(R.id.widget_row1, R.id.widget_row2, R.id.widget_row3)
        private val NAMES = intArrayOf(R.id.widget_row1_name, R.id.widget_row2_name, R.id.widget_row3_name)
        private val LEVELS = intArrayOf(R.id.widget_row1_level, R.id.widget_row2_level, R.id.widget_row3_level)
        private val SEGMENTS = intArrayOf(R.id.widget_seg1, R.id.widget_seg2, R.id.widget_seg3, R.id.widget_seg4)

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AllergyWidgetProvider::class.java))
            ids.forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.allergy_widget)
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val text = if (night) TEXT_DARK else TEXT_LIGHT
            val fill = if (night) FILL_DARK else FILL_LIGHT
            val muted = context.getColor(R.color.widget_muted)

            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            if (raw == null) {
                views.setTextViewText(R.id.widget_place, context.getString(R.string.app_name))
                views.setTextViewText(R.id.widget_level, context.getString(R.string.widget_empty))
                views.setViewVisibility(R.id.widget_bar, View.GONE)
                ROWS.forEach { views.setViewVisibility(it, View.GONE) }
                views.setTextViewText(R.id.widget_updated, "")
            } else {
                val data = JSONObject(raw)
                val level = data.optInt("level").coerceIn(0, 4)
                views.setTextViewText(R.id.widget_place, data.optString("place"))
                views.setTextViewText(R.id.widget_updated, updatedAt(data.optString("updated")))
                views.setTextViewText(R.id.widget_level, data.optString("levelLabel"))
                views.setTextColor(R.id.widget_level, text[level])
                views.setViewVisibility(R.id.widget_bar, View.VISIBLE)
                SEGMENTS.forEachIndexed { i, segId ->
                    views.setInt(segId, "setColorFilter", if (i < level) fill[level] else fill[0])
                }
                val allergens = data.optJSONArray("allergens")
                ROWS.forEachIndexed { i, rowId ->
                    val item = allergens?.optJSONObject(i)
                    if (item == null) {
                        views.setViewVisibility(rowId, View.GONE)
                    } else {
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(NAMES[i], item.optString("name"))
                        views.setTextViewText(LEVELS[i], levelText(context, item, text, muted))
                    }
                }
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

        /** «stima» piccola e grigia prima del livello, se il dato non viene da una previsione o da una misura. */
        private fun levelText(context: Context, item: JSONObject, colors: IntArray, muted: Int): CharSequence {
            val out = SpannableStringBuilder()
            if (item.optBoolean("estimate")) {
                out.append(context.getString(R.string.widget_estimate) + "  ")
                out.setSpan(ForegroundColorSpan(muted), 0, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                out.setSpan(RelativeSizeSpan(0.8f), 0, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            val start = out.length
            out.append(item.optString("levelLabel"))
            out.setSpan(ForegroundColorSpan(colors[item.optInt("level").coerceIn(0, 4)]), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            out.setSpan(StyleSpan(Typeface.BOLD), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            return out
        }

        private fun updatedAt(iso: String): String = try {
            val time = try {
                OffsetDateTime.parse(iso).toLocalTime()
            } catch (_: Exception) {
                LocalDateTime.parse(iso).toLocalTime()
            }
            time.format(DateTimeFormatter.ofPattern("HH:mm"))
        } catch (_: Exception) {
            ""
        }
    }
}
