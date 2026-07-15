# Riverpod 内部实现:脱离 Widget 树的依赖图

上一节的结论是 Provider 的三大局限都源于「依赖图寄生在 widget 树上」。Riverpod 的核心动作就一件事:**把依赖图搬出来,自建一套平行于 Element 树的运行时**。理解了这套运行时,你在面试里就能从"会用 Riverpod"跃迁到"能解释它为什么这样设计"。

------

## 一、iOS 概念映射

| Riverpod                  | iOS 最接近的类比                         | 说明                                      |
| ------------------------- | ---------------------------------------- | ----------------------------------------- |
| `ProviderContainer`       | Swinject 的 `Container` + 一层响应式缓存 | 全局对象图的持有者,但带生命周期和依赖追踪 |
| `Provider` (全局变量)     | Swinject 的注册 key / `ServiceEntry`     | 只是"配方"(recipe),不持有状态             |
| `ProviderElement`         | 被容器实例化后的对象 + Combine 订阅关系  | 真正持有 state 和依赖边的运行时节点       |
| `Ref`                     | 注入到工厂闭包里的 `Resolver`            | 但额外能建立响应式依赖                    |
| `autoDispose`             | 无直接对应;类似引用计数归零即释放        | 监听者数归零 → 销毁 state                 |
| `ProviderScope.overrides` | Swinject 测试时的重新注册 / mock 替换    | 编译期类型安全的替换                      |

关键心智转换:**Provider 全局变量 ≠ 全局状态**。它更像 Swinject 里的注册声明——immutable、无状态、只是一个身份标识 + 创建函数。状态活在 `ProviderContainer` 内部的 `ProviderElement` 里。

------

## 二、三层架构:Provider / Element / Container

```
Provider<T>            ← "配方",全局常量,类似 Swinject 注册
    │  (首次被 read/watch)
    ▼
ProviderElement<T>     ← 运行时节点:持有 state、依赖边、监听者列表
    │  (存放于)
    ▼
ProviderContainer      ← 哈希表 {Provider → ProviderElement} + 调度器
```

简化版内部逻辑:

```dart
class ProviderContainer {
  // 核心存储:每个 provider 对应一个懒创建的 element
  final _stateReaders = <Provider, ProviderElement>{};

  ProviderElement _readElement(Provider provider) {
    return _stateReaders.putIfAbsent(provider, () {
      final element = provider.createElement(this);
      element.mount();   // 执行 create 函数,建立依赖
      return element;
    });
  }
}
```

对照上一节:Provider 包用 `_inheritedElements` 哈希表挂在 Element 树上做 O(1) 查找;Riverpod 直接用**容器内一张哈希表**做同样的事——所以它不需要 `BuildContext`,这就是你能在 Dio interceptor 里 `container.read(authTokenProvider)` 的原因。

而 `ProviderScope` 只是一个把 `ProviderContainer` 塞进 InheritedWidget 的桥:widget 侧的 `ref.watch` 最终还是路由到容器。**InheritedWidget 在 Riverpod 里只剩一个职责:让 widget 找到 container,仅此而已。**

------

## 三、依赖追踪:`ref.watch` 如何建图

这是 Riverpod 和 Swinject 最大的分野。Swinject 的 `resolver.resolve()` 只发生在构造时一次;Riverpod 的 `ref.watch` 在**每次 provider 重算时动态登记依赖边**:

```dart
// 简化的 Ref.watch 逻辑
T watch<T>(Provider<T> dep) {
  final depElement = container._readElement(dep);
  // 双向登记:
  _dependencies.add(depElement);        // 我依赖了它
  depElement._dependents.add(this);     // 它被我依赖(subscription)
  return depElement.state;
}
```

由此形成一张有向图。当某个节点 state 变化:

```
authProvider 变化
    ↓ 遍历 _dependents
userProfileProvider 标记 dirty
    ↓ 递归传播
widget 侧的 WidgetRef 监听者 → markNeedsBuild()
```

⚠️ **重要细节:dirty 标记是惰性重算(lazy)**。上游变化只把下游标记为 dirty,并通知最末端的监听者;真正的重算发生在下一次被读取时。且 Riverpod 会做**值对比短路**:重算后若新值 `==` 旧值,传播链就此截断,下游不再 rebuild。这对应你已熟悉的 TanStack Query 心智——它是缓存图,不是事件总线。

**动态依赖**是另一个面试亮点:

```dart
final contentProvider = Provider((ref) {
  final isLoggedIn = ref.watch(authProvider);
  // 依赖边是"每次执行"动态建立的:
  return isLoggedIn
      ? ref.watch(privateFeedProvider)   // 登录时才存在这条边
      : ref.watch(publicFeedProvider);
});
```

每次重算前,element 会清空旧依赖边重新登记(类似 SwiftUI body 每次求值重建依赖)。Swinject 做不到这件事——它没有"重算"概念。

------

## 四、autoDispose 与生命周期:引用计数模型

`autoDispose` 的实现本质是**监听者引用计数**,这对 iOS 背景的你几乎零成本理解——它就是 ARC 思想在状态层的复刻:

```dart
// 简化逻辑
class AutoDisposeProviderElement {
  int get _listenerCount => _dependents.length + _externalListeners.length;

  void removeListener(listener) {
    _externalListeners.remove(listener);
    if (_listenerCount == 0) {
      container._scheduleDispose(this);  // 注意:不是立即销毁
    }
  }
}
```

⚠️ 两个高频陷阱:

1. **销毁是调度到帧末的**,不是同步的。页面 A → B 的瞬间,如果 B 立刻 watch 同一个 provider,state 不会丢——这避免了导航过渡期的闪断。
2. **`ref.keepAlive()`** 返回一个 `KeepAliveLink`,相当于手动持有一个"强引用",调用 `link.close()` 归还。典型用法:网络请求成功后 keepAlive 缓存结果,失败则允许销毁以便重试时重新请求:

```dart
@riverpod
Future<User> user(Ref ref) async {
  final user = await ref.watch(apiProvider).fetchUser();
  ref.keepAlive();  // 成功才缓存;抛异常则不执行,下次进入重新请求
  return user;
}
```

(你用 riverpod_generator,注意代码生成默认就是 autoDispose,`keepAlive: true` 才是需要显式声明的那个。)

------

## 五、Riverpod 3.x 值得点名的内部变化

面试报 3.x 版本时,这几点能体现你跟进了演进:

- **统一 `Ref`**:2.x 时代每个 provider 有专属 Ref 类型(`FutureProviderRef` 等),3.0 合并为单一 `Ref`,泛型简化。
- **自动重试(retry)**:provider 初始化抛异常时默认指数退避重试,这是内建在 element 生命周期里的。
- **离线持久化(experimental)**、**mutation(experimental)**:state 层内建副作用管理的方向。
- **`Notifier` 实例可能被重建**:3.x 里 invalidate 后 Notifier 对象本身会重新构造,不要在 Notifier 上存"不属于 state 的字段"——这是从 2.x 迁移最容易踩的坑。

------

## 六、面试 Q&A 速答

**Q: Riverpod 说自己"编译期安全",安全在哪?** A: Provider 是全局变量,引用它 = 引用一个确定存在的对象,不存在 Provider 包的 `ProviderNotFoundException`(运行时才发现树上没包 Provider)。同类型多实例也天然支持——两个 `Provider<String>` 是两个不同的变量身份,而 Provider 包按 runtimeType 查找会冲突。

**Q: 全局变量声明 provider,不是全局状态反模式吗?** A: 全局的是**定义**(immutable 配方),状态存在 `ProviderContainer` 里。测试时 `ProviderContainer(overrides: [...])` 新建容器即得到完全隔离的状态空间——这恰恰是可测试性的来源,等价于 Swinject 每个测试 new 一个 Container。

**Q: ref.watch 和 ref.listen / ref.read 的区别?** A: `watch` 建立依赖边,值变则重算/重建且参与缓存图传播;`listen` 只注册回调(做副作用如弹 toast、导航),不触发重建;`read` 一次性取值,无订阅。对应关系与 Provider 包的 watch/read 一致,但多了 `listen` 这个副作用通道。

**Q: UI 到底怎么刷新的?** A: `ConsumerWidget` 的 `ref.watch` 向 element 注册外部监听者,provider 值变化(且 `!=` 旧值)时回调触发该 widget 的 `markNeedsBuild`,walk 回归到 Flutter 正常的 build 管线。Riverpod 只负责"决定谁该刷新",刷新本身仍是 Element 树的机制。