package com.itsash.moon_locator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.itsash.moon_locator/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val json = call.arguments as? String
                    if (json == null) {
                        result.error("bad_args", "Expected a JSON string", null)
                    } else {
                        MoonWidget.store(applicationContext, json)
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
