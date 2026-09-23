import 'dart:ffi';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Hello Flutter"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 主轴对齐方式
      crossAxisAlignment: CrossAxisAlignment.start, // 交叉轴对齐方式
      children: [
        Expanded(
          flex: 1, // 弹性系数
          child: IconContainer(color: Colors.orange, icon: Icons.home),
        ),
        Expanded(
          flex: 2,
          child: IconContainer(color: Colors.green, icon: Icons.person),
        ),
      ],
    );
  }
}

class IconContainer extends StatelessWidget {
  Color color;
  IconData icon;
  IconContainer({super.key, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      color: color,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
