package com.example.janhelp

import android.os.PowerManager
import android.view.WindowManager
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
                        // Keep screen ON during AI call (SCREEN_BRIGHT_WAKE_LOCK keeps display lit)
                        @Suppress("DEPRECATION")
                        if (wakeLock == null || wakeLock?.isHeld == false) {
                            wakeLock = pm.newWakeLock(
                                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                "janhelp:voicecall"
                            ).also { it.acquire(30 * 60 * 1000L) } // max 30 min
                        }
                        // Also set window flag — safest modern approach
                        runOnUiThread {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "release" -> {
                        if (wakeLock?.isHeld == true) wakeLock?.release()
                        wakeLock = null
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
