import 'package:flutter/widgets.dart';

/// 课时状态。iOS 类比：就是 Swift 的 `enum LessonStatus { case locked... }`，
/// Dart 的 enum 同样支持 switch 穷举检查（漏 case 编译报错）。
enum LessonStatus {
  locked, // 未解锁：前置课时还没过关
  inProgress, // 进行中：当前正在学的课
  done, // 已完成：模拟器跑通 + analyze 0 + 全量测试过 + 学员确认
}

/// 一条课程注册信息。
/// 设计文档约定：注册表硬编码、不做持久化——进度的"真身"在
/// docs/lessons/README.md，这里只是它在 App 内的可视化副本。
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.scenario,
    required this.status,
    this.pageBuilder,
  });

  final String id; // 'L0'...'L9'
  final String title; // 课程主题
  final String scenario; // 企业真实场景，列表里当副标题
  final LessonStatus status;

  /// 课程入口页构造器。iOS 类比：类似存一个 `() -> UIViewController` 闭包，
  /// 用到时才真正创建页面（Flutter 里页面也是 Widget，没有 VC 这一层）。
  /// 还没实现的课时为 null。
  final WidgetBuilder? pageBuilder;
}
