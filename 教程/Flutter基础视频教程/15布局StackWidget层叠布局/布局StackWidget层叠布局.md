## StackWidget

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var stack = Stack(
      alignment: const FractionalOffset(0.5, 0.85),
      children: [
        const CircleAvatar(
          backgroundImage:
              NetworkImage('https://book.flutterchina.club/logo.png'),
          radius: 100.0,
        ),
        Container(
          child: const Text('我是文波'),
          padding: const EdgeInsets.all(5.0),
          decoration: const BoxDecoration(color: Colors.orangeAccent),
        )
      ],
    );

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

