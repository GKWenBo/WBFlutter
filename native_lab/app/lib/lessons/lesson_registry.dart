import 'lesson.dart';
import 'l0/l0_anatomy_page.dart';
import 'l1/l1_device_info_page.dart';

/// 课程注册表：App 首页列表的数据源。
/// 每课过关提交时手动翻状态；下一课开课时把它的 status 改成
/// inProgress 并补上 pageBuilder。
final List<Lesson> lessonRegistry = [
  Lesson(
    id: 'L0',
    title: '工程创建与原生工程解剖',
    scenario: '入职第一天：看懂 ios/ 和 android/ 到底是什么',
    status: LessonStatus.done,
    pageBuilder: (_) => const L0AnatomyPage(),
  ),
  Lesson(
    id: 'L1',
    title: 'MethodChannel：Flutter 调原生',
    scenario: '设备信息上报（机型/系统版本/电池）',
    status: LessonStatus.done,
    pageBuilder: (_) => const L1DeviceInfoPage(),
  ),
  const Lesson(
    id: 'L2',
    title: '数据编解码与复杂参数',
    scenario: '埋点桥：Flutter 埋点走原生统计 SDK',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L3',
    title: 'EventChannel：原生持续推流',
    scenario: '网络状态监听（弱网提示、断网重连）',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L4',
    title: '页面级混合 + 权限',
    scenario: 'Flutter 页跳原生扫码页，结果回传',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L5',
    title: 'Pigeon 类型安全生成',
    scenario: '手写 channel 魔法值重构为 Pigeon',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L6',
    title: 'PlatformView：视图级混合',
    scenario: '页面里嵌原生地图 MKMapView',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L7',
    title: '插件开发',
    scenario: '把设备信息桥抽成独立 plugin 包',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L8',
    title: 'add-to-app：原生工程接入 Flutter',
    scenario: '已有原生 App 用 CocoaPods 接入 Flutter 模块',
    status: LessonStatus.locked,
  ),
  const Lesson(
    id: 'L9',
    title: 'add-to-app：引擎管理与通信',
    scenario: '引擎预热、原生↔模块双向通信、路由协调',
    status: LessonStatus.locked,
  ),
];
