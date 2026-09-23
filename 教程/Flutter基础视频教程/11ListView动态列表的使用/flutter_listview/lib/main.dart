import 'package:flutter/material.dart';

void main() =>
    runApp(MyApp(
      items: new List<String>.generate(100, (index) => 'item $index'),));

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
          body: Center(
            child: Container(
                child: HorizontalList(items: items)
            ),
          )
      ),
    );
  }
}

class HorizontalList extends StatelessWidget {
  HorizontalList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('${items[index]}'),
            leading: Icon(Icons.star),
          );
        }
    );
  }
}
