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
        body: Center(
          child: Container(
            height: 200,
            child: HorizontalList()
          ),
        )
      ),
    );
  }
}

class HorizontalList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        Container(
          width: 220,
          color: Colors.orange,
        ),
        Container(
          width: 220,
          color: Colors.cyan,
        ),
        Container(
          width: 220,
          color: Colors.purple,
        )
      ],
    );
  }
}
