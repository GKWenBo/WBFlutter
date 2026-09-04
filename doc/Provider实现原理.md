# Provider 实现原理

> **适用版本**：provider 6.x / Flutter 3.x
> **后续阅读**：[Riverpod 实现原理](Riverpod实现原理.md) —— 本文末尾的三大局限就是 Riverpod 的设计动机
> **配套实战**：[state_lab S1 · 手写迷你 Provider](../state_lab/docs/tech/s1-状态管理的地基.md)、[state_lab S2 · Provider 版 MiniShop](../state_lab/docs/tech/s2-provider.md)
>
> ⚠️ 本文代码块中的"源码"均为**示意性伪代码**，用于说明机制，与真实实现不完全一致。

---

## 零、一句话总纲

即使项目里用的是 Riverpod，面试中「Provider 原理」几乎必考——因为它是理解 Flutter 依赖注入和 Riverpod 设计动机的基础。

**Provider = InheritedWidget 的语法糖 + ChangeNotifier 的监听桥接。**

---

## 一、iOS 概念映射

| Flutter | iOS 最接近的类比 | 差异点 |
| --- | --- | --- |
| `InheritedWidget` | SwiftUI `@EnvironmentObject` / `Environment` | 机制几乎同构：沿视图树向下传值，O(1) 查找 |
| `ChangeNotifier` | `ObservableObject` + `objectWillChange` | ChangeNotifier 是 `addListener` 回调式，更像 KVO / NotificationCenter |
| `context.watch` | `@EnvironmentObject var x`（自动订阅） | watch 注册依赖，数据变则 rebuild |
| `context.read` | 直接访问对象引用，不订阅 | 用于回调中，不触发 rebuild |
| `Consumer` | SwiftUI 中缩小 body 刷新范围的子 View | 控制 rebuild 粒度 |

如果你理解 SwiftUI 的 `EnvironmentObject` 是怎么从环境里取值并触发刷新的，Provider 你已经懂了七成。

---

## 二、底层基石：InheritedWidget 的 O(1) 查找

面试官问「Provider 原理」，第一层标准答案是 InheritedWidget 的两件事：**怎么找到、怎么通知**。

### 2.1 怎么找到：`_inheritedElements` 哈希表

每个 `Element` 上维护了一个从祖先传递下来的映射表（Flutter 3.7+ 是 `PersistentHashMap<Type, InheritedElement>`）：

```dart
// framework.dart 简化逻辑
abstract class Element {
  PersistentHashMap<Type, InheritedElement>? _inheritedElements;

  @override
  void mount(Element? parent, Object? newSlot) {
    // 挂载时从 parent 继承这张表
    _inheritedElements = parent?._inheritedElements;
  }
}

class InheritedElement extends ProxyElement {
  @override
  void _updateInheritance() {
    // InheritedElement 会把"自己"追加进表，再传给子树
    _inheritedElements = (parent?._inheritedElements ?? empty)
        .put(widget.runtimeType, this);
  }
}
```

所以 `context.dependOnInheritedWidgetOfExactType<T>()` **不是向上遍历树，而是查哈希表，O(1)**。

这是它和 iOS responder chain 逐级向上查找的本质区别——更像 SwiftUI Environment 的字典传播。

### 2.2 怎么通知：依赖注册 + `didChangeDependencies`

```dart
// watch 的底层
T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>() {
  final ancestor = _inheritedElements?[T];
  if (ancestor != null) {
    // 关键：把"当前 Element"注册到祖先的依赖集合里
    ancestor.updateDependencies(this, aspect);
    _dependencies.add(ancestor);
    return ancestor.widget as T;
  }
  return null;
}
```

当 `InheritedWidget` 重建时，框架调用 `updateShouldNotify(oldWidget)`，返回 `true` 就遍历依赖集合，对每个依赖者调用 `didChangeDependencies()` → `markNeedsBuild()` → 下一帧 rebuild。

> ⚠️ **面试高频陷阱**：`InheritedWidget` 自己不存储可变状态，它是 immutable 的。要"更新"，必须由上层（通常是 `StatefulWidget` 的 `setState`）重建一个新的 `InheritedWidget` 实例。
>
> 这就引出了 Provider 要解决的问题。

---

## 三、Provider 做了什么：把 ChangeNotifier 桥接到 InheritedWidget

裸用 InheritedWidget 需要手写 `StatefulWidget` 包一层来触发更新，Provider 把这套样板自动化了。核心链路：

```
ChangeNotifier.notifyListeners()
        ↓ （addListener 注册的回调）
_InheritedProviderScopeElement.markNeedsNotifyDependents()
        ↓
markNeedsBuild() → 下一帧 rebuild InheritedWidget
        ↓
notifyClients() → 遍历依赖者 didChangeDependencies()
        ↓
所有 watch 了它的 widget rebuild
```

简化版内部逻辑：

```dart
// provider 包内部（简化）
class _InheritedProviderScopeElement<T> extends InheritedElement {
  bool _shouldNotifyDependents = false;

  // ChangeNotifierProvider 在 startListening 时做的事：
  // notifier.addListener(() => element.markNeedsNotifyDependents());

  void markNeedsNotifyDependents() {
    _shouldNotifyDependents = true;
    markNeedsBuild();  // 让这个 InheritedElement 自己重建
  }

  @override
  Widget build() {
    if (_shouldNotifyDependents) {
      _shouldNotifyDependents = false;
      notifyClients(widget);  // 通知所有依赖者
    }
    return super.build();
  }
}
```

用 iOS 语言描述：**`notifyListeners()` ≈ `objectWillChange.send()`，而 Provider 扮演的角色 ≈ SwiftUI runtime 里把 publisher 事件转换成视图失效（invalidation）的那层胶水。**

---

## 四、read / watch / select 的实现差异

这是区分「会用」和「懂原理」的分水岭。

```dart
// context.watch<T>() —— 注册依赖
T watch<T>() => Provider.of<T>(this, listen: true);
// 底层：dependOnInheritedWidgetOfExactType → 注册进依赖表

// context.read<T>() —— 只取值，不注册
T read<T>() => Provider.of<T>(this, listen: false);
// 底层：getElementForInheritedWidgetOfExactType → 只查表拿 Element，不注册
```

`select` 则利用了 `InheritedElement` 的 **aspect 机制**（同 `InheritedModel` 的思路）：注册依赖时附带一个 selector 函数，通知阶段先对比 `selector(old) != selector(new)`，不同才 rebuild。

这就是细粒度刷新的实现，对应 Riverpod 里的 `ref.watch(provider.select(...))`。

> ⚠️ **经典 pitfall**：在 `build()` 里用 `read` 是反模式（数据变了 UI 不刷新）；在 `onPressed` 回调里用 `watch` 则是无意义的依赖注册。
>
> 规则：**build 用 watch，回调用 read。**

---

## 五、面试 Q&A 速答

**Q：Provider 为什么能跨 widget 找到数据？遍历树吗？**
A：不遍历。每个 Element 持有 `_inheritedElements` 哈希表，由父级逐层传递，InheritedElement 挂载时把自己写入表中，查找是 O(1)。

**Q：`notifyListeners` 到 UI 刷新的完整链路？**
A：Provider 在创建时对 ChangeNotifier `addListener`，回调里让对应的 InheritedElement `markNeedsBuild`；该 Element 重建时调用 `notifyClients`，遍历依赖集合触发每个依赖 Element 的 `didChangeDependencies → markNeedsBuild`，下一帧统一 rebuild。

**Q：`watch` / `read` / `select` 底层分别是什么？**
A：`watch` 走 `dependOnInheritedWidgetOfExactType`，注册进依赖表；`read` 走 `getElementForInheritedWidgetOfExactType`，只查表不注册；`select` 在注册时附带 selector（aspect 机制），通知阶段比对 selector 结果，不同才 rebuild。

**Q：InheritedWidget 自己能更新状态吗？**
A：不能，它是 immutable 的。必须由外层 `StatefulWidget` 重建一个新实例，Provider 做的就是把这套样板自动化。

---

## 六、Provider 的三大局限（引出 Riverpod）⭐

这是面试时从 Provider 过渡到 Riverpod 的最佳叙事线：

| # | 局限 | 具体表现 | Riverpod 的解法 |
| --- | --- | --- | --- |
| 1 | **依赖 BuildContext** | widget 树外（如 Dio interceptor、后台任务）拿不到数据 | 依赖图搬进 `ProviderContainer`，脱离树 |
| 2 | **按 runtimeType 查找** | 同一类型的多个实例难以区分 | Provider 变量的 identity 作 key，天然多实例 |
| 3 | **无编译期检查** | 忘记包 Provider 只能运行时抛 `ProviderNotFoundException` | Provider 是全局变量，引用即确定存在 |

三点的根源是同一件事：**依赖图寄生在 widget 树上**。Riverpod 把依赖图移出 widget 树，正是为了解决这三点——详见 [Riverpod 实现原理](Riverpod实现原理.md)。
