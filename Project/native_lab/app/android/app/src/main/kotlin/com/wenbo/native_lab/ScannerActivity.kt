package com.wenbo.native_lab

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout

/**
 * L4 模拟扫码页（原生 Activity）——Android 对照，对标 iOS 的 MockScannerViewController。
 *
 * 真机上这里是 CameraX / ZXing 的相机预览 + 二维码识别；对照/无相机场景用预置按钮 +
 * 输入框代替"扫到"，但 startActivity → setResult → finish 这条页面级混合主线是真实的：
 * - 扫到码：setResult(RESULT_OK, code) → MainActivity 的 scanLauncher 收到 → 回传 Dart；
 * - 用户按返回键：不 setResult → 默认 RESULT_CANCELED → MainActivity 当"取消"（回 null）。
 *
 * 用代码搭 UI（不写 XML 布局），保持与 iOS 侧一样"一个文件看全"。
 */
class ScannerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // L4 课后练习：用 Flutter 打开原生页时带下来的 hint 当标题（拿不到就用默认）。
        title = intent.getStringExtra("hint") ?: "模拟扫码（对照）"

        val field = EditText(this).apply { hint = "手动输入一个码" }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 96, 48, 48)
            addView(field)
            addView(button("扫到 SKU-10086") { finishWith("SKU-10086") })
            addView(button("扫到 COUPON-8") { finishWith("COUPON-8") })
            addView(button("确认输入的码") {
                val text = field.text?.toString().orEmpty()
                finishWith(text.ifEmpty { "EMPTY" })
            })
        }
        setContentView(root)
    }

    private fun finishWith(code: String) {
        setResult(RESULT_OK, Intent().putExtra("code", code))
        finish()
    }

    private fun button(label: String, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            setOnClickListener { onClick() }
        }
}
