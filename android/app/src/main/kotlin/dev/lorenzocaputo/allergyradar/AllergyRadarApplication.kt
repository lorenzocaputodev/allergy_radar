package dev.lorenzocaputo.allergyradar

import android.app.Application
import android.content.SharedPreferences
import dev.lorenzocaputo.allergyradar.widget.AllergyWidgetProvider

/** Ridisegna i widget a ogni scrittura dei loro dati, dall'app aperta o dal controllo in background. */
class AllergyRadarApplication : Application(), SharedPreferences.OnSharedPreferenceChangeListener {
    override fun onCreate() {
        super.onCreate()
        // SharedPreferences tiene i listener con un riferimento debole: l'Application vive quanto il processo.
        getSharedPreferences(AllergyWidgetProvider.PREFS, MODE_PRIVATE).registerOnSharedPreferenceChangeListener(this)
    }

    override fun onSharedPreferenceChanged(prefs: SharedPreferences?, key: String?) {
        if (key == AllergyWidgetProvider.KEY) AllergyWidgetProvider.updateAll(this)
    }
}
