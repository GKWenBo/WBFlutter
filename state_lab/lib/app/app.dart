import 'package:flutter/material.dart';

import 'version_list_page.dart';

/// StateLab 根 App（≈ AppDelegate + UIWindow 的装配层）。
class StateLabApp extends StatelessWidget {
  const StateLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StateLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const VersionListPage(),
    );
  }
}
