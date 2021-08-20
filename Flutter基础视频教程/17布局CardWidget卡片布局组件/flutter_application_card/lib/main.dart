import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var card = Card(
        child: Column(
      children: [
        ListTile(
          title: Text('重庆市渝北区', style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('收货员：113213213213'),
          leading: Icon(
            Icons.location_city,
          ),
          trailing: Icon(Icons.mark_chat_read),
        ),
        Divider(),
        ListTile(
            title:
                Text('重庆市江北区', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('收货员：113213213213'),
            leading: Icon(Icons.location_city),
            trailing: Icon(Icons.mark_chat_read)),
        Divider(),
        ListTile(
          title: Text('重庆市奉节县', style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('收货员：113213213213'),
          leading: Icon(Icons.location_city),
          trailing: Icon(Icons.mark_chat_read),
          onTap: () {
            print("点击了");
          },
          onLongPress: () {
            print("长按了");
          },
        )
      ],
    ));

    return MaterialApp(
      title: 'column widget',
      home: Scaffold(
          appBar: AppBar(
            title: const Text('column widget'),
          ),
          body: Center(
            child: card,
          )),
    );
  }
}
