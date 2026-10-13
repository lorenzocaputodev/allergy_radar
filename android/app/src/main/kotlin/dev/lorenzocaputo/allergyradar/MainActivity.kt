package dev.lorenzocaputo.allergyradar

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    // --- Canale della posizione ---
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enabled" -> result.success(locationEnabled())
                "permission" -> permission(call.argument<Boolean>("ask") == true, result)
                "current" -> current(result)
                else -> result.notImplemented()
            }
        }
    }

    private val manager get() = getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private fun granted() = checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED

    private fun locationEnabled(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        manager.isLocationEnabled
    } else {
        listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER).any { manager.isProviderEnabled(it) }
    }

    // --- Permesso ---
    private fun permission(ask: Boolean, result: MethodChannel.Result) {
        when {
            granted() -> result.success("granted")
            !ask -> result.success("denied")
            pendingPermission != null -> result.error("busy", "Richiesta di permesso già in corso", null)
            else -> {
                pendingPermission = result
                requestPermissions(arrayOf(PERMISSION), REQUEST_CODE)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val prefs = getSharedPreferences(PERMISSION_PREFS, MODE_PRIVATE)
        if (shouldShowRequestPermissionRationale(PERMISSION)) prefs.edit().putBoolean(DENIED_ONCE, true).apply()
        result.success(
            when {
                granted() -> "granted"
                shouldShowRequestPermissionRationale(PERMISSION) || !prefs.getBoolean(DENIED_ONCE, false) -> "denied"
                else -> "deniedForever"
            },
        )
    }

    // --- Posizione ---
    private fun providers(): List<String> {
        val candidates = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(LocationManager.FUSED_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(LocationManager.GPS_PROVIDER)
        }
        val available = manager.allProviders
        return candidates.filter { it in available && manager.isProviderEnabled(it) }
    }

    private fun lastKnown(): Location? = manager.allProviders
        .mapNotNull {
            try {
                manager.getLastKnownLocation(it)
            } catch (_: SecurityException) {
                null
            }
        }
        .filter { SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos <= LAST_KNOWN_MAX_AGE_NS }
        .maxByOrNull { it.elapsedRealtimeNanos }

    private fun current(result: MethodChannel.Result) {
        if (!granted()) return result.error("denied", "Permesso di posizione assente", null)
        val providers = providers()
        if (providers.isEmpty()) return reply(result, lastKnown())

        val handler = Handler(Looper.getMainLooper())
        var done = false
        var pending = providers.size
        val signal = CancellationSignal()
        val listeners = mutableListOf<LocationListener>()
        fun finish(location: Location?) {
            if (done) return
            done = true
            handler.removeCallbacksAndMessages(null)
            signal.cancel()
            listeners.forEach { manager.removeUpdates(it) }
            reply(result, location ?: lastKnown())
        }
        fun answer(location: Location?) {
            pending--
            if (location != null || pending <= 0) finish(location)
        }
        handler.postDelayed({ finish(null) }, TIMEOUT_MS)
        providers.forEach { provider ->
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    manager.getCurrentLocation(provider, signal, mainExecutor) { answer(it) }
                } else {
                    val listener = object : LocationListener {
                        override fun onLocationChanged(location: Location) = answer(location)

                        @Deprecated("Richiesto prima di Android 10")
                        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

                        override fun onProviderEnabled(provider: String) {}

                        override fun onProviderDisabled(provider: String) = answer(null)
                    }
                    listeners.add(listener)
                    @Suppress("DEPRECATION")
                    manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
                }
            } catch (_: Exception) {
                answer(null)
            }
        }
    }

    private fun reply(result: MethodChannel.Result, location: Location?) {
        result.success(location?.let { mapOf("lat" to it.latitude, "lon" to it.longitude) })
    }

    companion object {
        private const val CHANNEL = "dev.lorenzocaputo.allergyradar/location"
        private const val PERMISSION = Manifest.permission.ACCESS_COARSE_LOCATION
        private const val REQUEST_CODE = 4710
        private const val PERMISSION_PREFS = "location_permission"
        private const val DENIED_ONCE = "denied_once"
        private const val TIMEOUT_MS = 15_000L
        private const val LAST_KNOWN_MAX_AGE_NS = 60 * 60 * 1_000_000_000L
    }
}
