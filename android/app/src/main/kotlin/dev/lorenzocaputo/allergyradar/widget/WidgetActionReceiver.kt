package dev.lorenzocaputo.allergyradar.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AllergyWidgetProvider.ACTION_PAGE -> {
                val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                AllergyWidgetProvider.page(context, id, intent.getIntExtra(AllergyWidgetProvider.EXTRA_STEP, 1))
            }
            AllergyWidgetProvider.ACTION_REFRESH -> AllergyWidgetProvider.refresh(context)
        }
    }
}
