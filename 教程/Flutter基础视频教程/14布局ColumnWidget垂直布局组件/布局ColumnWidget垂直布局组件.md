## ColumnWidget

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'column widget',
      home: Scaffold(
        appBar: AppBar(
          title: Text('column widget'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Text('大家好'),
            ),
            Center(
              child: Text('我是文波'),
            ),
            Center(
              child: Text('很高兴认识大家'),
            )
          ],
        ),
      ),
    );
  }
}
```

