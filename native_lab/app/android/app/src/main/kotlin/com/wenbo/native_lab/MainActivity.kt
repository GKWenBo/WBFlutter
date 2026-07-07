package com.wenbo.native_lab

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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

        // L2：第二条 channel 并列注册（埋点桥）。内存 buffer 模拟统计 SDK。
        val analyticsBuffer = mutableListOf<Map<String, Any?>>()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wenbo.native_lab/analytics" // 与 Dart/iOS 逐字符一致
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "logEvent" -> {
                    // Dart Map 解码成 HashMap<String, Any?>。数字类型是坑：
                    // 小整数是 Integer、超 int32 的是 Long——想当数字用就 (x as Number).toXxx()，
                    // 直接 as Int 对大数会 ClassCastException（iOS 侧全是 NSNumber 无此坑）。
                    @Suppress("UNCHECKED_CAST")
                    val map = call.arguments as? Map<String, Any?>
                    if (map == null) {
                        result.error("BAD_ARGS", "logEvent 期望 Map", null)
                    } else {
                        analyticsBuffer.add(map)
                        result.success(analyticsBuffer.size) // 自增序号
                    }
                }
                "logBatch" -> {
                    // 顶层参数是数组：Dart List<Map> → ArrayList<HashMap>。
                    @Suppress("UNCHECKED_CAST")
                    val list = call.arguments as? List<Map<String, Any?>>
                    if (list == null) {
                        result.error("BAD_ARGS", "logBatch 期望 List<Map>", null)
                    } else {
                        analyticsBuffer.addAll(list)
                        result.success(analyticsBuffer.size) // 累加后的新总数
                    }
                }
                "fetchLoggedEvents" -> result.success(analyticsBuffer)
                "uploadRawLog" -> {
                    // 二进制：Dart Uint8List → ByteArray（iOS 是 FlutterStandardTypedData.data）。
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) {
                        result.error("BAD_ARGS", "uploadRawLog 期望二进制", null)
                    } else {
                        result.success(bytes.size)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // L3：第三条 channel，且是第一条 EventChannel（网络状态持续推流）。
        // 对照 iOS：StreamHandler 的 onListen/onCancel 两端命名一致（Flutter 统一），
        // 底层分别是 register/unregister NetworkCallback 与 NWPathMonitor 的 start/cancel。
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wenbo.native_lab/network_status" // 三端逐字符一致
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var callback: ConnectivityManager.NetworkCallback? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val cb = object : ConnectivityManager.NetworkCallback() {
                    // 回调在非主线程，事件要 runOnUiThread 投递（同 iOS 回主线程）。
                    // L3 课后练习：推 Map{'type','level'} 而非裸字符串（level 占位满格 3）,
                    // 与 iOS 端 events(["type":..., "level":...]) 逐字段对齐。
                    override fun onAvailable(network: Network) {
                        runOnUiThread { events.success(mapOf("type" to "wifi", "level" to 3)) }
                    }

                    override fun onLost(network: Network) {
                        runOnUiThread { events.success(mapOf("type" to "none", "level" to 0)) }
                    }
                }
                cm.registerDefaultNetworkCallback(cb)
                callback = cb
            }

            override fun onCancel(arguments: Any?) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                callback?.let { cm.unregisterNetworkCallback(it) }
                callback = null
            }
        })
    }
}
