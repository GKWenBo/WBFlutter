// =============================================================================
// Hero —— 共享元素转场
//
// 解决什么：列表页的小图，在 push 到详情页时"飞"过去变成大图；pop 时再飞回来。
// 用法：两个页面里用同一个 tag 的 Hero 包住对应元素，然后正常 Navigator.push 即可。
//
// iOS 对应：SwiftUI 的 matchedGeometryEffect(id:in:)；
//          UIKit 里要自己写 UIViewControllerAnimatedTransitioning + snapshot 才能做到。
//          Flutter 里两行代码搞定，这是 Flutter 动画的一大优势。
//
// 坑：
//   1. 同一个页面里 tag 必须唯一，否则报错 "multiple heroes that share the same tag"。
//   2. 飞行过程中 Hero 是放在 Overlay 里渲染的，如果子组件含 Text，
//      可能丢失 DefaultTextStyle（出现黄色下划线）→ 包一层 Material(type: transparency)。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class _Item {
  const _Item(this.id, this.name, this.color, this.icon);
  final int id;
  final String name;
  final Color color;
  final IconData icon;
}

const _items = [
  _Item(1, '日落', Colors.orange, Icons.wb_sunny),
  _Item(2, '海洋', Colors.blue, Icons.water),
  _Item(3, '森林', Colors.green, Icons.forest),
  _Item(4, '星空', Colors.indigo, Icons.nights_stay),
  _Item(5, '花园', Colors.pink, Icons.local_florist),
  _Item(6, '雪山', Colors.blueGrey, Icons.ac_unit),
];

class HeroDemo extends StatelessWidget {
  const HeroDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Hero 共享元素',
      iosAnalogy: '≈ SwiftUI matchedGeometryEffect / UIKit 自定义转场',
      tips: const [
        '两个页面的 Hero 用同一个 tag，正常 push/pop 就会自动飞行',
        '同一页面内 tag 必须唯一（列表里用 id 拼 tag）',
        '飞行中含 Text 可能出现黄色下划线 → 包 Material(type: transparency)',
      ],
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        shrinkWrap: true, // 放在外层滚动视图里，需要 shrinkWrap + 禁止自身滚动
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final item in _items)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _DetailPage(item: item)),
              ),
              child: Hero(
                tag: 'hero-${item.id}', // ⭐ 与详情页一致
                child: _Thumb(item: item, radius: 16, iconSize: 36),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.radius, required this.iconSize});

  final _Item item;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(item.icon, color: Colors.white, size: iconSize),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        children: [
          Hero(
            tag: 'hero-${item.id}', // ⭐ 与列表页一致
            child: SizedBox(
              height: 300,
              child: _Thumb(item: item, radius: 0, iconSize: 120),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '这是「${item.name}」的详情页。返回时，大图会飞回列表里的原位置。\n\n'
              '注意圆角从 16 变成 0 也被平滑过渡了：Hero 飞行时会对两端的 '
              '子组件做尺寸补间，内容本身则在飞行中显示目标页的版本。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
