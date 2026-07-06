import 'package:flutter/material.dart';

import 'home/lesson_list_page.dart';

void main() {
  runApp(const NativeLabApp());
}

class NativeLabApp extends StatelessWidget {
  const NativeLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeLab 原生实验室',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const LessonListPage(),
    );
  }
}
