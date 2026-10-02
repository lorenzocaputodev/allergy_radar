package dev.lorenzocaputo.allergyradar

import android.app.Application
import android.content.SharedPreferences
import dev.lorenzocaputo.allergyradar.widget.AllergyWidgetProvider

class AllergyRadarApplication : Application(), SharedPreferences.OnSharedPreferenceChangeListener {
    override fun onCreate() {
        super.onCreate()
        getSharedPreferences(AllergyWidgetProvider.PREFS, MODE_PRIVATE).registerOnSharedPreferenceChangeListener(this)
    }

    override fun onSharedPreferenceChanged(prefs: SharedPreferences?, key: String?) {
        if (key == AllergyWidgetProvider.KEY) AllergyWidgetProvider.updateAll(this)
    }
}
