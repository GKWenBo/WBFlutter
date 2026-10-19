import '../../../l10n/app_localizations.dart';

/// M12 国际化进阶：首页分类快捷入口的 slug → 当前语言的名字。
///
/// 为什么不让首页把翻译好的名字通过路由 `extra` 带给分类商品页：
/// extra 是 push 那一刻的**快照**。用户进了"手机"分类后去"我的"页切成德语，
/// StatefulShellRoute 会保留分类页的导航栈，标题却还是旧语言的"手机"。
/// 只传 slug、在目标页 build 时按当前语言翻译，切语言后自然跟着变。
///
/// 返回 null 表示这不是本地有翻译的分类（比如分类页列出的服务端分类名，本身就是接口原文）。
String? localizedCategoryName(AppLocalizations l10n, String slug) =>
    switch (slug) {
      'smartphones' => l10n.categoryPhones,
      'laptops' => l10n.categoryLaptops,
      'mens-watches' => l10n.categoryWatches,
      'tops' => l10n.categoryFashion,
      'mobile-accessories' => l10n.categoryAccessories,
      'beauty' => l10n.categoryBeauty,
      _ => null,
    };
