package com.wenbo.nl_device_kit

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/// 插件的 Android 入口。对照前 6 课在 MainActivity 里【手写注册】：
/// 这里实现 FlutterPlugin，onAttachedToEngine 里挂 channel，由框架【自动】调用。
class NlDeviceKitPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nl_device_kit")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getDeviceInfo" -> result.success(
                mapOf(
                    "model" to Build.MODEL,
                    "systemName" to "Android",
                    "systemVersion" to Build.VERSION.RELEASE,
                    "appVersion" to (context.packageManager
                        .getPackageInfo(context.packageName, 0).versionName ?: "unknown"),
                )
            )
            "getBatteryLevel" -> {
                val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (level < 0) result.error("UNAVAILABLE", "拿不到电量", null)
                else result.success(level)
            }
            "getSystemUpTime" -> result.success(SystemClock.elapsedRealtime() / 1000.0)
            "getDeviceModelName" -> result.success(Build.MODEL)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
