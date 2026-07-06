import 'package:flutter/material.dart';

import '../lessons/lesson.dart';
import '../lessons/lesson_registry.dart';

/// 首页：课程列表，就是进度表在 App 内的可视化副本。
class LessonListPage extends StatelessWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NativeLab 原生实验室')),
      body: ListView.separated(
        itemCount: lessonRegistry.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) =>
            _LessonTile(lesson: lessonRegistry[index]),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(lesson.id)),
      title: Text(lesson.title),
      subtitle: Text(lesson.scenario),
      // 状态图标用 switch 表达式穷举，漏一个状态编译器直接报错。
      // iOS 类比：Swift 的 switch 穷举 enum 同款好处。
      trailing: switch (lesson.status) {
        LessonStatus.locked => const Icon(Icons.lock_outline),
        LessonStatus.inProgress => const Icon(Icons.play_circle_outline),
        LessonStatus.done =>
          const Icon(Icons.check_circle, color: Colors.green),
      },
      onTap: () {
        final builder = lesson.pageBuilder;
        if (lesson.status == LessonStatus.locked || builder == null) {
          // 门禁：未解锁的课只给提示。
          // ScaffoldMessenger 类比 iOS 里全局管理 toast/HUD 的单例，
          // 好处是页面销毁了提示还能活着。
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('先完成前面的课时，再解锁 ${lesson.id}')),
            );
          return;
        }
        // 类比 UINavigationController.pushViewController。
        Navigator.of(context).push(MaterialPageRoute(builder: builder));
      },
    );
  }
}
