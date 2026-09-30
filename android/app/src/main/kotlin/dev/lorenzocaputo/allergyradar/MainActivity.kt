package dev.lorenzocaputo.allergyradar

import dev.lorenzocaputo.allergyradar.widget.AllergyWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.lorenzocaputo.allergyradar/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidgets" -> {
                        AllergyWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
