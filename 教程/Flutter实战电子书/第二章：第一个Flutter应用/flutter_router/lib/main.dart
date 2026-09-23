import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      // 注册路由表
      routes: {
        "new_page" : (context) => NewRouter(),
        "/" : (context) => MyHomePage(title: 'Flutter Demo Home Page'),
        "tip_route" : (context) => TipRoute(text: ModalRoute.of(context)?.settings.arguments.toString() ?? "")
      },
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        shadowColor: Colors.purple,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // var result =
            //     Navigator.push(context, MaterialPageRoute(builder: (context) {
            //   return TipRoute(
            //     text: "我是提示xxxx",
            //   );
            // }));
            // print("路由返回:$result");

            Navigator.pushNamed(context, "new_page", arguments: "hi");

          },
          child: Text("打开提示页"),
        ),
      ),
    );
  }
}

class TipRoute extends StatelessWidget {
  TipRoute({
    Key? key,
    required this.text, // 接收一个text参数
  }) : super(key: key);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("提示"),
      ),
      body: Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: Column(
            children: <Widget>[
              Text(text),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, "我是返回值"),
                child: Text("返回"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 获取路由参数
    var args = ModalRoute.of(context)?.settings.arguments;
    print(args);
    return Scaffold(
        appBar: AppBar(
          title: Text("New route"),
        ),
        body: Center(
          child: Text("This is a new route"),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            /// 返回上级界面
            Navigator.pop(context);
          },
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ));
  }
}