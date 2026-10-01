package dev.lorenzocaputo.allergyradar.widget

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Ultimo passo dell'aggiornamento chiesto dal widget: ridisegna con i dati appena scaricati. */
class WidgetUpdateWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        AllergyWidgetProvider.updateAll(applicationContext)
        return Result.success()
    }
}
