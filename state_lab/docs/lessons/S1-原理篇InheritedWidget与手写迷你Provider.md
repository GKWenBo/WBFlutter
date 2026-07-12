# S1 · 原理篇:InheritedWidget 与手写迷你 Provider

> StateLab 第二课。本课交付:CartController + 手写 MiniProvider(~40 行核心)+ v0 就地重构。
> 深度原理请读本课核心交付物:[s1-状态管理的地基](../tech/s1-状态管理的地基.md)(本讲义只管上课节奏,不复制它)。

## 一、本课重点

### 1. 两件事心智模型

所有 Flutter 状态管理 = **DI(状态对象放哪、子孙怎么拿到)+ 订阅(状态变了通知谁重建)**。本课手写这两个地基:

- `CartController extends ChangeNotifier` —— 订阅侧:改数据和发通知锁进同一扇门;
- `MiniProvider`(InheritedWidget + 自定义 InheritedElement)—— DI 侧 + 把通知接到依赖者身上。

类比 iOS:合起来就是 SwiftUI 的 `.environmentObject(model)` + `@EnvironmentObject`,只是 Flutter 把魔法拆成了看得见的两个零件。

### 2. S0 四大痛点逐条谢幕(本课的验收标准)

| S0 痛点 | 重构后去哪了 |
|---|---|
| ① 层层传参(详情页 6 参) | 构造函数只剩业务参数(`product`/`api`);共享状态树上自取 |
| ② 双重 setState | 删光。一份状态一处通知:controller 开火 → 依赖者自动重建 |
| ③ pop 返回陈旧 UI(你抓的 bug) | `await push + setState` 补丁删光,回归测试原样通过——结构性修复 |
| ④ 重建范围粗暴 | `of()` 收进小 `Builder`:加购时只有角标块重建,商品卡不陪跑 |

### 3. of() / read() 的分工(S2 的 watch/read 前身)

- `of()` = 取值 **+ 登记依赖**:只能在 build/didChangeDependencies 里调;notifier 开火,登记者重建。
- `read()` = 只取值:事件回调、initState 里用;绝不因数据变化重建。
- 口诀:**展示用 of,动手用 read**。依赖粒度 = 调 of() 的那个 Element,想收窄就把 of() 推进更小的 Builder。

### 4. InheritedWidget 不跨路由(你那个 bug 的完整答案)

查找走的是沿 Element 父链复制传递的哈希表;push 出来的路由挂在 Navigator 之下,父链不经过发起页。所以每条 push 都要把**同一个 controller 实例**再包一层 MiniProvider(≈ S2 的 `Provider.value`)。忘了包?`of()` 当场断言"这条路由包了吗?"——比 v0 的默默陈旧强多了。

## 二、代码地图

```
state_lab/lib/versions/v0_setstate/
  state/                                  # ⭐ 本课新增:v0 的状态层
    cart_controller.dart                  # ChangeNotifier:只读视图 + 四个变更方法
    mini_provider.dart                    # 手写迷你 Provider(InheritedNotifier 思路)
  v0_shop_root.dart                       # 根瘦身:创建/dispose controller + 挂 provider
  pages/product_list_page.dart            # 6 参→1 参;of() 收进 Builder 圈依赖粒度
  pages/product_detail_page.dart          # 双重 setState、await 补丁删光
  pages/cart_page.dart                    # ⭐ Stateful → Stateless(假 Stateful 现形)
  pages/search_page.dart                  # 同上;防抖/序号等私有状态照旧 setState
state_lab/test/versions/v0_setstate/
  cart_controller_test.dart               # 6 测:行为 + 通知次数 + 只读视图
  mini_provider_test.dart                 # 4 测:of 订阅重建 / read 不重建 / 断言
```

对照重构前:`git diff 93abcd2 HEAD -- state_lab/lib/versions/v0_setstate/`。

## 三、控件/API 速查表(本课新面孔)

| 控件/API | iOS 类比 | 怎么用 | 易踩的坑 |
|---|---|---|---|
| `InheritedWidget` | SwiftUI `Environment` | 子类持 final 数据 + `updateShouldNotify`;挂树后子孙按类型查 | 自身不可变;"数据变了通知"要配 Listenable |
| `dependOnInheritedWidgetOfExactType` | `@EnvironmentObject` | build 里调,取值+订阅 | initState 里调直接断言;这是 watch/read 分工的框架级原因 |
| `getInheritedWidgetOfExactType` | 取对象不观察 | 回调/initState 里调 | 拿来当展示数据源会"不跟新" |
| `ChangeNotifier` | `ObservableObject` | 变更方法末尾 `notifyListeners()` | 忘 dispose 泄漏;build 期间开火同款 setState-during-build 异常 |
| `ValueNotifier<T>` | 单个 `@Published` | `value` 赋新值即通知(`==` 判断) | 装 List 改内容不换引用 = 不通知 |
| `ListenableBuilder` | Combine sink 局部刷新 | `listenable:` + `builder:`,不走树上查找 | 记得配 `child` 缓存大子树(ValueListenableBuilder 同) |
| `Builder` | 无直接对应 | 就地开一个新 Element/context | 本课用途:圈住 of() 的依赖登记范围,收窄重建 |
| `List.unmodifiable` | `NSArray`(不可变拷贝) | getter 里包一层再交出去 | 每次调用都拷贝,大列表高频调用要留意 |

## 四、关键实验(模拟器上做)

1. **依赖粒度**:列表页加购一件 → `列表角标` RebuildBadge +1,商品卡计数**纹丝不动**(S0 课后练习里卡片是全员陪跑的,对比记住这两个数字)。
2. **你的 bug 复验**:详情页加购 → 进购物车清空 → 返回详情页,角标**自动**清零——这次代码里没有任何 await/setState 补丁。
3. **断言体验**(可选):把 `_openDetail` 里的 MiniProvider 包装临时去掉,点商品 → 红屏"这条路由包了吗?"——感受"当场炸"优于"默默陈旧"。
4. 常规场景表照走:分页/刷新/搜索防抖/购物车增删/合计。

## 五、自测清单

1. `of()` 和 `read()` 各做了什么?分别允许在哪些时机调用?为什么 initState 里不能 `dependOn`?
2. 为什么每条 push 都要 re-provide?包进去的是新 controller 还是同一个实例?对应 Provider 的哪个 API?
3. MiniProvider 的自定义 Element 为什么必须订阅 notifier?InheritedWidget 天生的通知路径是哪条、缺了哪条?
4. `updateShouldNotify` 在日常 `notifyListeners` 刷新时会被调用吗?它到底管什么场景?
5. 购物车页为什么能从 Stateful 变 Stateless?"假 Stateful"是什么代码味?
6. 依赖(重建)的粒度由什么决定?列表页是怎么让商品卡不陪跑的?S2/S3/S4 各自对应的收窄工具叫什么?
7. CartController 为什么要用 `List.unmodifiable` 交出数据?它封死了 v0 的哪个病灶?
8. controller 谁创建、谁 dispose?忘了 dispose 会怎样?
9. v0 重构后还剩哪些 setState?为什么它们**应该**留下?
10. `Theme.of(context)` 和本课机制什么关系?

(答案先自己写,S1 过关后我出对照版归档 `自测答案/`。)

## 六、课后练习

把详情页收藏心形改成第三种通知工具:`ValueNotifier<bool> _favorite` + `ValueListenableBuilder`,体会"不经过树、直接订阅"的写法;跑通后 **revert 回 setState 版**(保持 v0 版本纯净,这个练习只为手感)。

进阶思考(不写代码):如果把 MiniProvider 提到 MaterialApp 之上,哪些代码可以删?代价是什么?——这就是 S2 Provider 的标准姿势,带着答案去上课。
