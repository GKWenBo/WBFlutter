# M1 首页静态 UI（纯本地假数据）

> 本课产出：一个像样的电商首页——顶部搜索框（假）、Banner 轮播、横向分类入口、
> 双列商品网格。**全部用本地写死的假数据**（M2 换成真 model，M3 换成网络数据）。
> 这一课练的是 Flutter 的看家本领：**组合式 UI + 可复用组件 + 布局防溢出**。

---

## 一、本课重点掌握（按重要程度排序）

### 1. 一切皆 Widget，UI 靠"组合"而不是"继承/配置" ⭐⭐⭐

- iOS 里你给一个 `UIView` 设一堆属性（`backgroundColor`、`layer.cornerRadius`…）；
  Flutter 里这些是**一层层套的 Widget**：圆角要 `ClipRRect`、内边距要 `Padding`、
  背景色要 `Container`/`ColoredBox`、居中要 `Center`。
- 一开始会觉得"套娃"很啰嗦，但它换来的是**每一层职责单一、可任意重排**。
  ≈ SwiftUI 的 modifier 链，只是 Flutter 把 modifier 也做成了独立 Widget。
- 记忆钩子：**看到一个视觉效果，先想"这是哪个 Widget 的职责"，而不是"设哪个属性"。**

### 2. 把可变状态"下沉"，页面尽量 `StatelessWidget` ⭐⭐⭐

- 首页整体是 `StatelessWidget`（后来 M4 因为要滚动分页才升级成 Stateful）。
  Banner "当前在第几页"这种会变的状态，**封在 `HomeBanner` 子组件内部**，不污染首页。
- 原则：**状态放在"真正需要它"的最小子树里**。一个页面里只有 Banner 需要记页码，
  就别让整个首页变成 Stateful——否则页码一变整页重建（这正是 M13 要收拾的性能问题的根源）。
- iOS 对照：别把一个 cell 的局部状态提到整个 VC 上管。

### 3. 抽可复用组件：`ProductCard` / `CategoryChip` / `SectionHeader` ⭐⭐

- 商品卡、分类入口、区块标题各抽成一个 Widget 放 `presentation/widgets/`。
  ≈ 你把重复的 UI 抽成自定义 `UIView`/SwiftUI `View`。
- 判断"该不该抽"：**出现第二次、或内部有自己的布局逻辑**，就抽。
- 好处在 M3 兑现：数据从假变真时，卡片组件一行不用改，只换喂给它的数据。

### 4. 布局防溢出：`RenderFlex overflowed` 是新手第一坑 ⭐⭐

- `Row`/`Column` 里子组件总尺寸超过可用空间，就报黄黑警戒条 `RenderFlex overflowed by N px`。
- 三种解法，对症下药：
  - 文字会超长 → 给 `Text` 设 `maxLines` + `overflow: TextOverflow.ellipsis`（≈ `numberOfLines`）。
  - 子组件要按比例吃掉剩余空间 → 用 `Expanded`/`Flexible` 包住（≈ 约束里的 `contentHugging`/`compressionResistance`）。
  - 内容本来就可能超屏 → 换成可滚动容器（`ListView`/`SingleChildScrollView`）。
- 记忆钩子：**看到黄黑斑马线，先问"谁没被约束住"。**

### 5. 网络图用 `Image.network`，务必配占位/错误态 ⭐⭐

- `Image.network(url)` 加载中默认是空白，失败会抛红。真实 App 一定要给：
  `loadingBuilder`（转圈占位）、`errorBuilder`（加载失败的兜底图）。
- 图片有固定展示区就配 `AspectRatio` 锁比例，避免图片到货前后高度跳动导致列表"抽搐"。
- （M13 会再加 `cacheWidth` 限制解码尺寸省内存——这一课先跑通。）

---

## 二、新控件速查表

| 控件 | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `Container` | `UIView`（背景/边框/圆角/内外边距一把梭） | 设 `decoration: BoxDecoration(...)`、`padding`、`margin` | 只做单一效果时用更轻的 `Padding`/`ColoredBox`/`SizedBox`，别 Container 万能锤 |
| `Row` / `Column` | `UIStackView`（横向/纵向） | `children` 排列子组件，`mainAxisAlignment`/`crossAxisAlignment` 管对齐 | 子组件超尺寸就溢出；要按比例分空间必须配 `Expanded`/`Flexible` |
| `Expanded` / `Flexible` | Auto Layout 的 hugging/compression 优先级 | 包在 Row/Column 的子组件外，`flex:` 分配权重 | 只能用在 Flex 容器（Row/Column）里，放别处报错 |
| `Stack` / `Positioned` | `ZStack` / 绝对定位 addSubview | `Stack.children` 叠放，`Positioned` 精确定位某一层 | Stack 默认按最大子组件撑开；Positioned 只能在 Stack 里用 |
| `PageView` | `UIPageViewController` / 开分页的 UIScrollView | `controller` 控制翻页，`onPageChanged` 回调页码 | 要有界高度；记页码的状态别提到整页（见 HomeBanner 的封装） |
| `GridView` / `SliverGrid` | `UICollectionView`（网格布局） | `gridDelegate` 定列数/间距/宽高比 | 长列表**必须**用 `.builder`（懒构建）；`childAspectRatio` 设不对会溢出 |
| `AspectRatio` | 约束宽高比 | `aspectRatio: 16/7` 锁比例 | 父级要能给它一个有界的宽或高，否则约束无解 |
| `ClipRRect` | `layer.cornerRadius` + `masksToBounds` | 包住子组件裁圆角 | 裁剪有性能成本（M13）；能用 `BoxDecoration.borderRadius` 就别额外裁 |
| `const` 构造 | 编译期常量单例 | 不依赖运行时数据的 Widget 前面加 `const` | 加了 const 的 Widget 在重建时**被跳过**，是最省事的性能优化（M13 详述） |

---

## 三、代码地图

```
lib/features/products/presentation/
  home_page.dart             首页（M1 是 Stateless，M4 升级 Stateful 做分页）
  widgets/
    home_banner.dart         Banner 轮播（页码状态封在内部）
    category_chip.dart        横向分类入口的单个圆图标
    product_card.dart         商品卡（缩略图/标题/价格/评分）
    section_header.dart       "为你推荐"这种区块标题 + "更多"
本地假数据：M1 写在页面里的 List/record，M3 全部换成网络数据
```

---

## 四、自测清单

1. 想给一个 `Text` 加圆角背景 + 内边距，要套哪几层 Widget？各自负责什么？
2. 首页只有 Banner 需要记页码，为什么不把整页做成 StatefulWidget？
3. `RenderFlex overflowed` 的三种典型成因，各自用什么解？
4. 一个只依赖固定文案的 Widget 前面加 `const`，重建时会发生什么？

---

## 五、练习

故意把 `ProductCard` 的标题换成一段很长的文字，让它撑爆卡片触发 `RenderFlex overflowed`，
然后用 `maxLines` + `ellipsis` 修好。亲手制造一次溢出再修复，比看十遍文档都记得牢。
