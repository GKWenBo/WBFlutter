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

/// 底部弹层本体。用 State 持有"正在保存"标志：
/// 保存要等写盘完成，这期间用户可能连点两个语言——如果每次点击都各自 select + pop，
/// 第二次 pop 时弹层已经在退场动画里了，pop 掉的会是**弹层下面的页面**（比如登录页）。
/// 所以保存中忽略后续点击，整个弹层只 pop 一次（≈ iOS 里提交中禁用按钮防重复触发）。
class _LanguageSheet extends ConsumerStatefulWidget {
  const _LanguageSheet();

  @override
  ConsumerState<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<_LanguageSheet> {
  bool _saving = false;

  Future<void> _choose(Locale? locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await runUiAction(
      context,
      () => ref.read(appLocaleProvider.notifier).select(locale),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false); // 失败（已提示）：允许重新选择
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(appLocaleProvider).asData?.value;

    // 选项：跟随系统 + 所有已翻译的语言。直接用 gen-l10n 生成的 supportedLocales，
    // 新增一个 app_xx.arb 后这里自动多一行，不需要手动维护第二份列表。
    final options = <(Locale?, String)>[
      (null, l10n.languageFollowSystem),
      for (final locale in AppLocalizations.supportedLocales)
        (locale, languageEndonym(locale)),
    ];

    return SafeArea(
      // 底部弹层默认最多占屏高的 9/16：横屏、大字号、或者以后语言变多时，
      // 固定的 Column 会溢出（Widget 测试在 800×600 画布上就抓到了溢出 23px）。
      // 内容可能超过容器高度时就该可滚动 ≈ 给 UIStackView 外面套一个 UIScrollView。
      child: SingleChildScrollView(
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
                enabled: !_saving, // 保存中整组变灰、不可点
                onTap: () => _choose(locale),
              ),
          ],
        ),
      ),
    );
  }
}
