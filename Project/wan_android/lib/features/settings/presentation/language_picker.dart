import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/run_ui_action.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/locale_providers.dart';

/// 语言的"自称"（endonym）：每种语言用它自己的文字写自己的名字。
///
/// 这几个名字**故意不放进 ARB 翻译**：如果用户手滑切到了看不懂的阿拉伯语，
/// 列表里还写着 "الصينية"（阿语的"中文"）他就找不回来了；写 "简体中文" 才认得出。
/// iOS 系统设置 → 语言与地区 列表也是同样的做法。
String languageEndonym(Locale locale) => switch (locale.languageCode) {
  'zh' => '简体中文',
  'en' => 'English',
  'de' => 'Deutsch',
  'ar' => 'العربية',
  // 新加了 ARB 却忘了补这里时，至少显示语言代码而不是崩溃。
  _ => locale.toLanguageTag(),
};

/// 打开语言选择底部弹层 ≈ iOS 的 UIAlertController(.actionSheet) / SwiftUI .confirmationDialog。
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _LanguageSheet(),
  );
}

/// AppBar 上的语言按钮（登录页用：未登录也要能改语言）。
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.translate),
      tooltip: AppLocalizations.of(context).language,
      onPressed: () => showLanguagePicker(context),
    );
  }
}

/// "我的"页菜单里的语言行：标题 + 当前语言名 + 箭头。
class LanguageMenuTile extends ConsumerWidget {
  const LanguageMenuTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appLocaleProvider).asData?.value;
    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text(l10n.language),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected == null
                ? l10n.languageFollowSystem
                : languageEndonym(selected),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          // chevron_right 定义里带 matchTextDirection: true，阿语下会自动翻成向左的箭头，
          // 不用自己判断方向（≈ UIImage.imageFlippedForRightToLeftLayoutDirection）。
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => showLanguagePicker(context),
    );
  }
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appLocaleProvider).asData?.value;

    // 选项：跟随系统 + 所有已翻译的语言。直接用 gen-l10n 生成的 supportedLocales，
    // 新增一个 app_xx.arb 后这里自动多一行，不需要手动维护第二份列表。
    final options = <(Locale?, String)>[
      (null, l10n.languageFollowSystem),
      for (final locale in AppLocalizations.supportedLocales)
        (locale, languageEndonym(locale)),
    ];

    Future<void> choose(Locale? locale) async {
      final saved = await runUiAction(
        context,
        () => ref.read(appLocaleProvider.notifier).select(locale),
      );
      if (saved && context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.languagePickerTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final (locale, label) in options)
            ListTile(
              title: Text(label),
              // 用对勾表示选中，而不是 RadioListTile：新版 Flutter 的 Radio 改成了 RadioGroup 托管，
              // 单选列表用 ListTile + 对勾更直观，也 ≈ iOS 设置页的 checkmark 样式。
              trailing: locale == selected ? const Icon(Icons.check) : null,
              onTap: () => choose(locale),
            ),
        ],
      ),
    );
  }
}
