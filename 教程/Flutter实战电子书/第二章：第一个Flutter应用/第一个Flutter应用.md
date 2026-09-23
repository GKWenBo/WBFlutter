### 计数器应用实例

### 路由管理

#### MaterialPageRoute

`MaterialPageRoute`继承自`PageRoute`类，`PageRoute`类是一个抽象类，表示占有整个屏幕空间的一个模态路由页面，它还定义了路由构建及切换时过渡动画的相关接口及属性。`MaterialPageRoute` 是Material组件库提供的组件，它可以针对不同平台，实现与平台页面切换动画风格一致的路由切换动画：

- 对于Android，当打开新页面时，新的页面会从屏幕底部滑动到屏幕顶部；当关闭页面时，当前页面会从屏幕顶部滑动到屏幕底部后消失，同时上一个页面会显示到屏幕上。
- 对于iOS，当打开页面时，新的页面会从屏幕右侧边缘一致滑动到屏幕左边，直到新页面全部显示到屏幕上，而上一个页面则会从当前屏幕滑动到屏幕左侧而消失；当关闭页面时，正好相反，当前页面会从屏幕右侧滑出，同时上一个页面会从屏幕左侧滑入。

#### Navigator

`Navigator`是一个路由管理的组件，它提供了打开和退出路由页方法。`Navigator`通过一个栈来管理活动路由集合。通常当前屏幕显示的页面就是栈顶的路由。`Navigator`提供了一系列方法来管理路由栈，在此我们只介绍其最常用的两个方法：

##### [#](https://book.flutterchina.club/chapter2/flutter_router.html#future-push-buildcontext-context-route-route)Future push(BuildContext context, Route route)

将给定的路由入栈（即打开新的页面），返回值是一个`Future`对象，用以接收新路由出栈（即关闭）时的返回数据。

##### [#](https://book.flutterchina.club/chapter2/flutter_router.html#bool-pop-buildcontext-context-result)bool pop(BuildContext context, [ result ])

将栈顶路由出栈，`result`为页面关闭时返回给上一个页面的数据。

`Navigator` 还有很多其它方法，如`Navigator.replace`、`Navigator.popUntil`等，详情请参考API文档或SDK源码注释，在此不再赘述。下面我们还需要介绍一下路由相关的另一个概念“命名路由”。

#### 命名路由

- 注册路由表

```dart
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
        "/" : (context) => MyHomePage(title: 'Flutter Demo Home Page')
      },
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```

- 通过路由名打开新路由页

```dart
onPressed: () {
  Navigator.pushNamed(context, "new_page");
  //Navigator.push(context,
  //  MaterialPageRoute(builder: (context) {
  //  return NewRoute();
  //}));  
},
```

- 命名路由参数传递

```dart
class NewRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 获取路由参数 
    var args = ModalRoute.of(context)?.settings.arguments;
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
          child: const Icon(Icons.backpack_sharp),
        ));
  }
}
```

在打开路由时传递参数

```dart
Navigator.pushNamed(context, "new_page", arguments: "hi");
```

#### 路由生成钩子

`MaterialApp`有一个`onGenerateRoute`属性，它在打开命名路由时可能会被调用，之所以说可能，是因为当调用`Navigator.pushNamed(...)`打开命名路由时，如果指定的路由名在路由表中已注册，则会调用路由表中的`builder`函数来生成路由组件；如果路由表中没有注册，才会调用`onGenerateRoute`来生成路由。`onGenerateRoute`回调签名如下：

```dart
Route<dynamic> Function(RouteSettings settings)
```

有了`onGenerateRoute`回调，要实现上面控制页面权限的功能就非常容易：我们放弃使用路由表，取而代之的是提供一个`onGenerateRoute`回调，然后在该回调中进行统一的权限控制，如：

```dart
MaterialApp(
  ... //省略无关代码
  onGenerateRoute:(RouteSettings settings){
	  return MaterialPageRoute(builder: (context){
		   String routeName = settings.name;
       // 如果访问的路由页需要登录，但当前未登录，则直接返回登录页路由，
       // 引导用户登录；其它情况则正常打开路由。
     }
   );
  }
);
```

### 包管理

#### 依赖包网址

https://pub.dev/

```ruby
name: flutter_in_action
description: First Flutter application.

version: 1.0.0+1

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^0.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
    
flutter:
  uses-material-design: true
```

- 将“english_words”（4.0.0版本）添加到依赖项列表，如下：

```
english_words: ^4.0.0
```

- 下载包。在Android Studio的编辑器视图中查看pubspec.yaml时（图2-6），单击右上角的 **Packages get** 。

- 引入`english_words`包。

```dart
import 'package:english_words/english_words.dart';
```

- 使用`english_words`包来生成随机字符串。

#### 其它依赖方式

- 依赖本地包

  ```
  dependencies:
  	pkg1:
          path: ../../code/pkg1
  ```

- 依赖Git：你也可以依赖存储在Git仓库中的包。如果软件包位于仓库的根目录中，请使用以下语法

  ```
  dependencies:
    pkg1:
      git:
        url: git://github.com/xxx/pkg1.git
  ```

  上面假定包位于Git存储库的根目录中。如果不是这种情况，可以使用path参数指定相对位置，例如：

  ```
  dependencies:
    package1:
      git:
        url: git://github.com/flutter/packages.git
        path: packages/package1        
  ```

### 资源管理

### 调试Flutter应用

### Flutter异常捕获

#### Flutter框架异常捕获

#### Dart单线程模型

在Java和Objective-C（以下简称“OC”）中，如果程序发生异常且没有被捕获，那么程序将会终止，但是这在Dart或JavaScript中则不会！究其原因，这和它们的运行机制有关系。Java和OC都是多线程模型的编程语言，任意一个线程触发异常且该异常未被捕获时，就会导致整个进程退出。但Dart和JavaScript不会，它们都是单线程模型，运行机制很相似(但有区别)

Dart 在单线程中是以消息循环机制来运行的，其中包含两个任务队列，一个是“微任务队列” **microtask queue**，另一个叫做“事件队列” **event queue**。从图中可以发现，微任务队列的执行优先级高于事件队列。

```dart
@override
void performRebuild() {
 ...
  try {
    //执行build方法  
    built = build();
  } catch (e, stack) {
    // 有异常时则弹出错误提示  
    built = ErrorWidget.builder(_debugReportException('building $this', e, stack));
  } 
  ...
} 
```

#### 异常捕获上报

```dart
void collectLog(String line){
    ... //收集日志
}
void reportErrorAndLog(FlutterErrorDetails details){
    ... //上报错误和日志逻辑
}

FlutterErrorDetails makeDetails(Object obj, StackTrace stack){
    ...// 构建错误信息
}

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    reportErrorAndLog(details);
  };
  runZoned(
    () => runApp(MyApp()),
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        collectLog(line); // 收集日志
      },
    ),
    onError: (Object obj, StackTrace stack) {
      var details = makeDetails(obj, stack);
      reportErrorAndLog(details);
    },
  );
}
```

