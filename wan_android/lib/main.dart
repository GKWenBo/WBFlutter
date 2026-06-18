import 'package:flutter/material.dart';

import 'app/app.dart';

// 程序入口。对应 iOS 的 @main / AppDelegate。
// runApp() 把根 Widget 挂到屏幕上，相当于设置 UIWindow.rootViewController 并 makeKeyAndVisible。
//
// 我们刻意把 main.dart 保持得极薄——它只负责"启动"，
// 真正的应用装配（主题、首页、以后的路由）都放到 app/app.dart 里。
// 这样以后接入状态管理（M4 的 ProviderScope）时，改动点很集中。
void main() {
  runApp(const WanShopApp());
}
