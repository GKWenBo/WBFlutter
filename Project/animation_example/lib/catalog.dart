import 'package:flutter/material.dart';

import 'demos/custom/custom_painter_demo.dart';
import 'demos/explicit/animated_builder_demo.dart';
import 'demos/explicit/animation_controller_demo.dart';
import 'demos/explicit/curves_gallery_demo.dart';
import 'demos/explicit/staggered_demo.dart';
import 'demos/explicit/transitions_demo.dart';
import 'demos/gesture/dismissible_demo.dart';
import 'demos/gesture/drag_spring_demo.dart';
import 'demos/implicit/animated_container_demo.dart';
import 'demos/implicit/animated_cross_fade_demo.dart';
import 'demos/implicit/animated_switcher_demo.dart';
import 'demos/implicit/animated_widgets_demo.dart';
import 'demos/implicit/tween_animation_builder_demo.dart';
import 'demos/list/animated_list_demo.dart';
import 'demos/transition/hero_demo.dart';
import 'demos/transition/page_route_demo.dart';

/// 一个 Demo 条目。新增 Demo 只需要在 [demoCategories] 里加一行。
class DemoEntry {
  const DemoEntry({
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

/// 一个分类（首页的一组）。
class DemoCategory {
  const DemoCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.entries,
  });

  final String name;
  final String description;
  final IconData icon;
  final List<DemoEntry> entries;
}

/// 学习顺序 = 列表顺序：隐式 → 显式 → 转场 → 列表 → 手势物理 → 自绘。
final List<DemoCategory> demoCategories = [
  DemoCategory(
    name: '1. 隐式动画',
    description: '改属性值 → 自动补间，最常用，优先考虑',
    icon: Icons.auto_awesome,
    entries: [
      DemoEntry(
        title: 'AnimatedContainer',
        subtitle: '尺寸/颜色/圆角一起变 ≈ UIView.animate',
        builder: (_) => const AnimatedContainerDemo(),
      ),
      DemoEntry(
        title: 'AnimatedXxx 合集',
        subtitle: 'Opacity / Align / Padding / Positioned / TextStyle',
        builder: (_) => const AnimatedWidgetsDemo(),
      ),
      DemoEntry(
        title: 'AnimatedSwitcher',
        subtitle: '子组件替换时过渡（换 key 才会触发）',
        builder: (_) => const AnimatedSwitcherDemo(),
      ),
      DemoEntry(
        title: 'AnimatedCrossFade / AnimatedSize',
        subtitle: '展开收起、两个状态交叉淡入淡出',
        builder: (_) => const AnimatedCrossFadeDemo(),
      ),
      DemoEntry(
        title: 'TweenAnimationBuilder',
        subtitle: '任意值的隐式动画：进度环、数字滚动',
        builder: (_) => const TweenAnimationBuilderDemo(),
      ),
    ],
  ),
  DemoCategory(
    name: '2. 显式动画',
    description: '自己持有 AnimationController，可播放/暂停/反向/循环',
    icon: Icons.tune,
    entries: [
      DemoEntry(
        title: 'AnimationController 控制台',
        subtitle: 'forward / reverse / repeat / stop ≈ CABasicAnimation',
        builder: (_) => const AnimationControllerDemo(),
      ),
      DemoEntry(
        title: 'XxxTransition 合集',
        subtitle: 'Fade / Scale / Rotation / Slide / Size',
        builder: (_) => const TransitionsDemo(),
      ),
      DemoEntry(
        title: 'AnimatedBuilder',
        subtitle: '呼吸灯、加载转圈，child 参数避免重建',
        builder: (_) => const AnimatedBuilderDemo(),
      ),
      DemoEntry(
        title: '交错动画 Staggered',
        subtitle: 'Interval 让列表项依次入场 ≈ beginTime',
        builder: (_) => const StaggeredDemo(),
      ),
      DemoEntry(
        title: 'Curves 曲线画廊',
        subtitle: '常用缓动曲线对比 ≈ CAMediaTimingFunction',
        builder: (_) => const CurvesGalleryDemo(),
      ),
    ],
  ),
  DemoCategory(
    name: '3. 页面转场',
    description: 'Hero 共享元素、自定义路由动画',
    icon: Icons.swap_horiz,
    entries: [
      DemoEntry(
        title: 'Hero 共享元素',
        subtitle: '列表小图飞到详情大图 ≈ matchedGeometryEffect',
        builder: (_) => const HeroDemo(),
      ),
      DemoEntry(
        title: '自定义页面转场',
        subtitle: 'PageRouteBuilder：淡入/上滑/缩放',
        builder: (_) => const PageRouteDemo(),
      ),
    ],
  ),
  DemoCategory(
    name: '4. 列表动画',
    description: '插入/删除带动画',
    icon: Icons.list,
    entries: [
      DemoEntry(
        title: 'AnimatedList',
        subtitle: '≈ tableView.insertRows(at:with:)',
        builder: (_) => const AnimatedListDemo(),
      ),
    ],
  ),
  DemoCategory(
    name: '5. 手势与物理',
    description: '手势驱动、弹簧回弹、3D 翻转',
    icon: Icons.touch_app,
    entries: [
      DemoEntry(
        title: '拖拽 + 弹簧回弹',
        subtitle: 'SpringSimulation ≈ UISpringTimingParameters',
        builder: (_) => const DragSpringDemo(),
      ),
      DemoEntry(
        title: '滑动删除 & 卡片翻转',
        subtitle: 'Dismissible + Matrix4.rotationY',
        builder: (_) => const DismissibleDemo(),
      ),
    ],
  ),
  DemoCategory(
    name: '6. 自绘动画',
    description: 'CustomPainter + Controller，想画啥画啥',
    icon: Icons.brush,
    entries: [
      DemoEntry(
        title: 'CustomPainter 动画',
        subtitle: '进度环 strokeEnd、波浪 ≈ CAShapeLayer',
        builder: (_) => const CustomPainterDemo(),
      ),
    ],
  ),
];
