## PositionedWidget

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var stack = Stack(alignment: const FractionalOffset(0.5, 0.85),
        // ignore: prefer_const_literals_to_create_immutables
        children: [
          const CircleAvatar(
            backgroundImage:
                NetworkImage('https://book.flutterchina.club/logo.png'),
            radius: 100.0,
          ),
          const Positioned(
            child: Text('我是文波'),
            top: 10.0,
            left: 50.0,
          ),
          const Positioned(
            child: Text('www.wenbo.blog.com'),
            bottom: 10.0,
            right: 10.0,
          )
        ]);

    return MaterialApp(
      title: 'column widget',
      home: Scaffold(
          appBar: AppBar(
            title: const Text('column widget'),
          ),
          body: Center(
            child: stack,
          )),
    );
  }
}
```

