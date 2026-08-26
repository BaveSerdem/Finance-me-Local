package com.financeme.local

import android.app.ActivityManager
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CLEAR_DATA_CHANNEL = "com.financeme.local/clear_data"

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CLEAR_DATA_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "clearAppData") {
                val activityManager =
                    getSystemService(ACTIVITY_SERVICE) as ActivityManager
                val success = activityManager.clearApplicationUserData()
                // clearApplicationUserData() kills the app process shortly
                // after returning true, on all supported API levels (minSdk 26
                // here). The result.success call below may or may not actually
                // reach Dart before the process dies — that's expected and
                // fine, do not treat a missing Dart-side response as an error.
                result.success(success)
            } else {
                result.notImplemented()
            }
        }
    }
}
