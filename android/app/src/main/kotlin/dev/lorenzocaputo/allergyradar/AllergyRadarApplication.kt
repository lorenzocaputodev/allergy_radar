package dev.lorenzocaputo.allergyradar

import android.app.Application
import dev.lorenzocaputo.allergyradar.widget.AllergyWidgetProvider

class AllergyRadarApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AllergyWidgetProvider.watch(this)
    }
}
