package dev.lorenzocaputo.allergyradar.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.content.res.Configuration
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.graphics.Typeface
import android.view.View
import android.widget.RemoteViews
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.lorenzocaputo.allergyradar.R
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Widget minimale: luogo e ora in alto, livello del giorno con barra a 4 segmenti, poi gli allergeni seguiti,
 * tanti quanti ne stanno nell'altezza; gli altri si scorrono con le frecce.
 * Legge i dati che l'app scrive in SharedPreferences (chiave flutter.widget_data),
 * quindi si aggiorna anche con l'app chiusa, dopo il controllo in background.
 */
class AllergyWidgetProvider : AppWidgetProvider() {

    // --- Eventi ---
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    // Ridimensionato dall'utente: cambia quante righe ci stanno.
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PAGE -> {
                val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                val pages = context.getSharedPreferences(PAGES, Context.MODE_PRIVATE)
                pages.edit().putInt("$id", pages.getInt("$id", 0) + intent.getIntExtra(EXTRA_STEP, 1)).apply()
                update(context, AppWidgetManager.getInstance(context), id)
            }
            ACTION_REFRESH -> refresh(context)
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.widget_data"
        private const val PAGES = "allergy_widget_pages"
        private const val ACTION_PAGE = "dev.lorenzocaputo.allergyradar.widget.PAGE"
        private const val EXTRA_STEP = "step"
        private const val ACTION_REFRESH = "dev.lorenzocaputo.allergyradar.widget.REFRESH"

        // Nome del compito Dart: in AlertsService fa riscaricare i dati anche se recenti.
        private const val REFRESH_TASK = "widget_refresh"

        // Altezze in dp rispetto a quella dichiarata dal launcher (che di solito tiene fuori i suoi margini):
        // intestazione con livello e barra, una riga di allergene, la barra delle frecce.
        private const val HEADER_DP = 100
        private const val ROW_DP = 22
        private const val PAGER_DP = 28

        // Colori per livello 0–4, come nella scala dell'app: testo e riempimento dei segmenti.
        private val TEXT_LIGHT = intArrayOf(0xFF5C6661.toInt(), 0xFF76580A.toInt(), 0xFF94470A.toInt(), 0xFFA63A1B.toInt(), 0xFF7A2338.toInt())
        private val TEXT_DARK = intArrayOf(0xFF9AA49E.toInt(), 0xFFEBCB6E.toInt(), 0xFFF0A860.toInt(), 0xFFF2825E.toInt(), 0xFFF08CA2.toInt())
        private val FILL_LIGHT = intArrayOf(0xFFE4E1D7.toInt(), 0xFFEFD27F.toInt(), 0xFFE59A48.toInt(), 0xFFC4502B.toInt(), 0xFF7A2338.toInt())
        private val FILL_DARK = intArrayOf(0xFF2C3632.toInt(), 0xFFE3C46E.toInt(), 0xFFE0913F.toInt(), 0xFFD0613A.toInt(), 0xFFB23A55.toInt())
        private val ROWS = intArrayOf(
            R.id.widget_row1, R.id.widget_row2, R.id.widget_row3, R.id.widget_row4, R.id.widget_row5, R.id.widget_row6,
        )
        private val NAMES = intArrayOf(
            R.id.widget_row1_name, R.id.widget_row2_name, R.id.widget_row3_name,
            R.id.widget_row4_name, R.id.widget_row5_name, R.id.widget_row6_name,
        )
        private val LEVELS = intArrayOf(
            R.id.widget_row1_level, R.id.widget_row2_level, R.id.widget_row3_level,
            R.id.widget_row4_level, R.id.widget_row5_level, R.id.widget_row6_level,
        )
        private val SEGMENTS = intArrayOf(R.id.widget_seg1, R.id.widget_seg2, R.id.widget_seg3, R.id.widget_seg4)

        // --- Disegno ---
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
                views.setViewVisibility(R.id.widget_pager, View.GONE)
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
                val total = allergens?.length() ?: 0
                val perPage = rowsFor(manager, id, total)
                val pageCount = ((total + perPage - 1) / perPage).coerceAtLeast(1)
                // La pagina salvata può superare l'ultima (frecce, meno allergeni): si riparte dalla prima.
                val page = Math.floorMod(context.getSharedPreferences(PAGES, Context.MODE_PRIVATE).getInt("$id", 0), pageCount)
                ROWS.forEachIndexed { i, rowId ->
                    val item = if (i < perPage) allergens?.optJSONObject(page * perPage + i) else null
                    if (item == null) {
                        // Sull'ultima pagina le righe vuote tengono il posto: frecce e titolo non si spostano.
                        val keep = i < perPage && pageCount > 1
                        views.setViewVisibility(rowId, if (keep) View.INVISIBLE else View.GONE)
                        views.setTextViewText(NAMES[i], "")
                        views.setTextViewText(LEVELS[i], "")
                    } else {
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(NAMES[i], item.optString("name"))
                        views.setTextViewText(LEVELS[i], levelText(context, item, text, muted))
                    }
                }
                views.setViewVisibility(R.id.widget_pager, if (pageCount > 1) View.VISIBLE else View.GONE)
                views.setTextViewText(R.id.widget_page, "${page + 1}/$pageCount")
                views.setOnClickPendingIntent(R.id.widget_prev, pageIntent(context, id, -1))
                views.setOnClickPendingIntent(R.id.widget_next, pageIntent(context, id, 1))
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pending = PendingIntent.getActivity(
                    context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }
            val refresh = Intent(context, AllergyWidgetProvider::class.java).setAction(ACTION_REFRESH)
            views.setOnClickPendingIntent(
                R.id.widget_refresh,
                PendingIntent.getBroadcast(context, 0, refresh, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )
            manager.updateAppWidget(id, views)
        }

        // --- Aggiornamento e pagine ---
        /**
         * Scarica i dati nuovi con lo stesso compito Dart del controllo orario, poi ridisegna i widget.
         * Senza rete il primo passo aspetta che torni.
         */
        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AllergyWidgetProvider::class.java))
            ids.forEach { id ->
                val views = RemoteViews(context.packageName, R.layout.allergy_widget)
                views.setTextViewText(R.id.widget_updated, context.getString(R.string.widget_updating))
                manager.partiallyUpdateAppWidget(id, views)
            }
            val fetch = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(Data.Builder().putString(BackgroundWorker.DART_TASK_KEY, REFRESH_TASK).build())
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            val redraw = OneTimeWorkRequest.Builder(WidgetUpdateWorker::class.java).build()
            WorkManager.getInstance(context)
                .beginUniqueWork(REFRESH_TASK, ExistingWorkPolicy.REPLACE, fetch)
                .then(redraw)
                .enqueue()
        }

        /** Quante righe di allergeni stanno nell'altezza attuale del widget (1–6). */
        private fun rowsFor(manager: AppWidgetManager, id: Int, total: Int): Int {
            val height = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            if (height == 0) return minOf(3, ROWS.size)
            val all = (height - HEADER_DP) / ROW_DP
            val rows = if (total > all) (height - HEADER_DP - PAGER_DP) / ROW_DP else all
            return rows.coerceIn(1, ROWS.size)
        }

        private fun pageIntent(context: Context, id: Int, step: Int): PendingIntent {
            val intent = Intent(context, AllergyWidgetProvider::class.java)
                .setAction(ACTION_PAGE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                .putExtra(EXTRA_STEP, step)
            return PendingIntent.getBroadcast(
                context, id * 2 + if (step > 0) 1 else 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
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
