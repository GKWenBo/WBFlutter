import 'package:flutter/material.dart';

// 主函数（入口函数）
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // 重写build方法
  @override
  Widget build(BuildContext context) {
    // 返回一个Material风格的组件
    return MaterialApp(
      title: 'Welcome to Flutter',
      color: Colors.orange,
      home: Scaffold(
        // 创建一个Bar，并添加文本
        appBar: AppBar(title: Text('Welcome to Flutter')),
        // 在主体的中间区域，添加一个hello world 的文本
        body: Center(
          child: Text(
            'Hello World',
            style: TextStyle(
                fontSize: 20,
                color: Colors.purple
            ),
          ),
        ),
      ),
    );
  }
}
