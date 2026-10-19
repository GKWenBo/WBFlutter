/// M12 国际化进阶：把各种书写体系的数字统一成 ASCII 0–9。
///
/// 为什么需要：阿拉伯语（及波斯语/乌尔都语）键盘默认输入的是"阿拉伯-印度数字"
///   ٠١٢٣٤٥٦٧٨٩（U+0660–0669）或"东阿拉伯-印度数字" ۰۱۲۳۴۵۶۷۸۹（U+06F0–06F9）。
/// 它们在屏幕上是正确的数字，但 `int.tryParse('١٣٨')` 返回 null——
/// 阿语用户会永远过不了"手机号必须是 11 位数字"的校验，后端也存进一串看不懂的字符。
///
/// 规则：**校验和存储前先归一化**；显示时交给 intl 按 locale 决定用哪种数字。
/// ≈ iOS 里 NumberFormatter(locale: en_US_POSIX) 解析用户输入，再按用户 locale 显示。
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660); // ٠-٩ → 0-9
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0); // ۰-۹ → 0-9
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
