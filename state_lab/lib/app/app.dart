import 'package:flutter/material.dart';

/// StateLab 根 App（≈ AppDelegate + UIWindow 的装配层）。
class StateLabApp extends StatelessWidget {
  const StateLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StateLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      // T4 会换成方案列表页 VersionListPage。
      home: const Scaffold(body: Center(child: Text('StateLab 施工中'))),
    );
  }
}
