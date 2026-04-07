package com.example.janhelp

import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "janhelp/wakelock")
            .setMethodCallHandler { call, result ->
                val pm = getSystemService(POWER_SERVICE) as PowerManager
                when (call.method) {
                    "acquire" -> {
                        if (wakeLock == null || wakeLock?.isHeld == false) {
                            wakeLock = pm.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK,
                                "janhelp:voicecall"
                            ).also { it.acquire(30 * 60 * 1000L) } // max 30 min
                        }
                        result.success(null)
                    }
                    "release" -> {
                        if (wakeLock?.isHeld == true) wakeLock?.release()
                        wakeLock = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
