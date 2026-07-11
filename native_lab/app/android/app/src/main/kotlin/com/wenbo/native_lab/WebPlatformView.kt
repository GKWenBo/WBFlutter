package com.wenbo.native_lab

import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/// PlatformView 工厂（对照 iOS 的 MapViewFactory）。createArgsCodec = StandardMessageCodec，
/// 必须和 Dart 侧对齐。Flutter 每嵌一个 native_view，就调一次 create 产出一个实例。
class WebViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return WebPlatformView(context, viewId, args, messenger)
    }
}

/// 单个嵌入的 WebView 实例 + 本实例专属方法通道（对照 iOS 的 MapPlatformView）。
class WebPlatformView(
    context: Context,
    viewId: Int,
    args: Any?,
    messenger: BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val webView = WebView(context)

    init {
        webView.webViewClient = WebViewClient() // 链接在本 WebView 内打开，不外跳浏览器
        webView.settings.javaScriptEnabled = true
        // 读创建参数里的初始 URL（对照 iOS 读初始地图区域）。
        val url = (args as? Map<*, *>)?.get("url") as? String ?: "https://flutter.dev"
        webView.loadUrl(url)

        // 每实例一条通道：名字带 viewId（对照 iOS 同名规则）。
        MethodChannel(messenger, "com.wenbo.native_lab/native_view_$viewId")
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "reload" -> { webView.reload(); result.success(null) }
            "loadUrl" -> {
                val url = call.arguments as? String
                if (url != null) { webView.loadUrl(url); result.success(null) }
                else result.error("BAD_ARGS", "loadUrl 需要 String", null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView() = webView
    override fun dispose() { webView.destroy() }
}
