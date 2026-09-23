import 'package:flutter/material.dart';
import './res/list_data.dart';

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
  MyHomePage({super.key}) {
    print(listData);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(scrollDirection: Axis.vertical, children: _initListData());
  }

  // List<Widget> _initListData() {
  //   var list = <Widget>[];
  //   for (int i = 0; i < 20; i++) {
  //     list.add(
  //       ListTile(title: Text("我是一个列表---$i"), subtitle: Text("Hello Flutter")),
  //     );
  //   }
  //   return list;
  // }

  //   List<Widget> _initListData() {
  //     return listData.map((item) {
  //       return ListTile(
  //         title: Text(item['title']),
  //         subtitle: Text(item['author']),
  //         leading: Image.network(item['imageUrl']),
  //       );
  //     }).toList();
  //   }

  List<Widget> _initListData() {
    var list = <Widget>[];
    for (var item in listData) {
      list.add(
        ListTile(
          title: Text(item["title"]),
          subtitle: Text(item["author"]),
          leading: Image.network(item["imageUrl"]),
        ),
      );
    }
    return list;
  }
}
