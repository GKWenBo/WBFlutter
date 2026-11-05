// =============================================================================
// AnimatedList —— 插入 / 删除带动画的列表
//
// iOS 对应：tableView.insertRows(at:with: .automatic) / deleteRows(at:with:)
//          或 UICollectionViewDiffableDataSource 的 apply(animatingDifferences: true)
//
// 和 iOS 一样的心智：数据源 和 UI 要"手动同步"——
//   插入：先改数据 _items.insert(i, x)，再 _listKey.currentState!.insertItem(i)
//   删除：先拿到被删的数据，改数据 _items.removeAt(i)，再 removeItem(i, builder)
//         ⭐ removeItem 需要一个 builder 来画"正在消失的那一行"（因为数据已经删掉了）
//
// 坑：数据源和 insertItem/removeItem 不同步 → 越界崩溃（和 iOS 的
//    "Invalid update: invalid number of rows" 是同一类错误）。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedListDemo extends StatefulWidget {
  const AnimatedListDemo({super.key});

  @override
  State<AnimatedListDemo> createState() => _AnimatedListDemoState();
}

class _AnimatedListDemoState extends State<AnimatedListDemo> {
  // GlobalKey 用来拿到 AnimatedListState，调用 insertItem / removeItem（≈ 持有 tableView 引用）
  final _listKey = GlobalKey<AnimatedListState>();
  final List<int> _items = [1, 2, 3];
  int _nextId = 4;

  static const _duration = Duration(milliseconds: 350);

  void _insert() {
    const index = 0; // 插到最前面
    _items.insert(index, _nextId++); // ① 先改数据
    _listKey.currentState!.insertItem(index, duration: _duration); // ② 再通知 UI
  }

  void _remove(int index) {
    final removed = _items.removeAt(index); // ① 先改数据（记下被删的值）
    // ② 通知 UI，并提供"消失中那一行"的样子
    _listKey.currentState!.removeItem(
      index,
      (context, animation) => _buildRow(removed, animation, removing: true),
      duration: _duration,
    );
  }

  /// 行的入场/出场动画：高度展开(SizeTransition) + 淡入。
  /// 插入时 animation 0→1；删除时 animation 1→0。
  Widget _buildRow(int value, Animation<double> animation, {bool removing = false}) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: FadeTransition(
        opacity: animation,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(child: Text('$value')),
            title: Text('Item $value'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              // 正在消失的行不响应点击；正常行点删除时实时查找下标（列表会变化，不能缓存 index）
              onPressed: removing ? null : () => _remove(_items.indexOf(value)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'AnimatedList',
      iosAnalogy: '≈ tableView.insertRows / deleteRows(with: .automatic)',
      tips: const [
        '先改数据源，再 insertItem / removeItem，两者必须同步',
        'removeItem 要传 builder 画"正在消失的行"（数据已删）',
        '更复杂的 diff 场景可以考虑 SliverAnimatedList 或第三方 diff 库',
      ],
      scrollable: false, // AnimatedList 自己会滚动
      child: Stack(
        children: [
          AnimatedList(
            key: _listKey,
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            initialItemCount: _items.length,
            itemBuilder: (context, index, animation) => _buildRow(_items[index], animation),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(onPressed: _insert, child: const Icon(Icons.add)),
          ),
        ],
      ),
    );
  }
}
