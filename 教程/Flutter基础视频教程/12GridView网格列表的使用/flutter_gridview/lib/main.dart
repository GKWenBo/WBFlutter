import 'package:flutter/material.dart';

void main() => runApp(MyApp(
      items: new List<String>.generate(100, (index) => 'item $index'),
    ));

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.items}) : super(key: key);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'List View',
      home: Scaffold(
          appBar: AppBar(
            title: Text('List View'),
          ),
          body: MyImageGridView()),
    );
  }
}

class MyGridView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(20.0),
      crossAxisSpacing: 10.0,
      children: [Text('文波'), Text('文波'), Text('文波'), Text('文波'), Text('文波')],
    );
  }
}

class MyImageGridView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2.0,
          crossAxisSpacing: 2.0,
          childAspectRatio: 0.7),
      children: [
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover)
      ],
    );
  }
}
