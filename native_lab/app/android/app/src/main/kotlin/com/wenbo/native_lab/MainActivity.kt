package com.wenbo.native_lab

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 对照 iOS：configureFlutterEngine ≈ didInitializeImplicitFlutterEngine，
    // 都是"引擎就绪，来挂你的 channel"的回调。
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wenbo.native_lab/device_info" // 三端逐字符一致
        ).setMethodCallHandler { call, result ->
            // 这里跑在 Android 主线程（= Platform 线程），与 iOS 同款约定。
            when (call.method) {
                "getDeviceInfo" -> result.success(
                    mapOf(
                        "model" to Build.MODEL,
                        "systemName" to "Android",
                        "systemVersion" to Build.VERSION.RELEASE,
                        "appVersion" to (packageManager
                            .getPackageInfo(packageName, 0).versionName ?: "unknown"),
                    )
                )
                "getBatteryLevel" -> {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    if (level < 0) {
                        result.error("UNAVAILABLE", "拿不到电量", null)
                    } else {
                        result.success(level)
                    }
                }
                "getSystemUpTime" -> {
                    val time = android.os.SystemClock.elapsedRealtime() / 1000.0
                    result.success(time)
                }
                else -> result.notImplemented()
            }
        }
    }
}
