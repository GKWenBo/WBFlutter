## ListViwe

### ListView的声明

```dart
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'List View',
      home: Scaffold(
        appBar: AppBar(
          title: Text('List View'),
        ),
        body: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.access_alarm),
              title: Text('access_alarm'),
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('add'),
            ),
            ListTile(
              leading: Icon(Icons.add_a_photo),
              title: Text('add_a_photo'),
            )
          ],
        )
      ),
    );
  }
}
```

### 图片列表的使用

```dart
class ImageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Image.network(
            'https://book.flutterchina.club/assets/img/book.17ed07e5.png'
        ),
        Image.network(
            'https://book.flutterchina.club/assets/img/book.17ed07e5.png'
        ),
        Image.network(
            'https://book.flutterchina.club/assets/img/book.17ed07e5.png'
        )
      ],
    );
  }
}
```

