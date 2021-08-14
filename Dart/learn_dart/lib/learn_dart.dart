library learn_dart;

import 'dart:ffi';

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;

  int add(int a, int b) {
    return a + b;
  }
}

main() {
  example1();

  testb(() => isNoble(1));

  example2();

  example3();

  var r = say("a", "b", "c");
  print(r);

  enableFlags(bold: true, hidden: false);

  example4();

  example5();

  example6();

  example7();

  example8();

  example9();
}

// final和const
void example1() {
  final str = "hello world";
  const str1 = "world hello";
  print(str);
}

// 函数
// 函数声明
typedef bool CallBack();
bool isNoble(int atomicNumber) {
  return true;
}

void testb(CallBack cb) {
  print(cb());
}

// 函数作为变量
void example2() {
  var say = (str) {
    print(str);
  };

  say("example2");
}

// 函数作为参数传递
void example3() {
  void excute(var callback) {
    callback();
  };
  
  excute(() => print("xxxx"));
}

// 可选的位置参数
String say(String from, String to, String? device) {
  var result = '$from says $to';
  if (device != null) {
    result = '$result with a $device';
  }
  return result;
}

// 可选的命名参数
//设置[bold]和[hidden]标志
void enableFlags({required bool bold, required bool hidden}) {
  // ...
}

/* 异步支持 */
// Future
void example5() {
  Future.delayed(new Duration(seconds: 2), () {
    return "hi world!";
  }).then((data) {
    print(data);
  });
}

// Future.catchError
void example4() {
  Future.delayed(new Duration(seconds: 2), () {
    //return "hi world!";
    throw AssertionError("Error");
  }).then((data) {
    print("success");
  }, onError: (e) {
    print(e);
  });
}

// Future.whenComplete
void example6() {
  Future.delayed(new Duration(seconds: 2),(){
    //return "hi world!";
    throw AssertionError("Error");
  }).then((data){
    //执行成功会走到这里
    print(data);
  }).catchError((e){
    //执行失败会走到这里
    print(e);
  }).whenComplete((){
    //无论成功或失败都会走到这里
  });
}

// Future.wait
void example7() {
  Future.wait([
    // 2秒后返回结果
    Future.delayed(new Duration(seconds: 2), () {
      return "hello";
    }),
    // 4秒后返回结果
    Future.delayed(new Duration(seconds: 4), () {
      return " world";
    })
  ]).then((results){
    print(results[0]+results[1]);
  }).catchError((e){
    print(e);
  });
}

/* Async/await */
void example8() {
  Future<String> getUserInfo(String userInfo) async {
    // 保存用户信息
    return "user info";
  };

  Future<String> login(String userInfo, String password) async {
    // 保存用户信息
    return "user info";
  };

  Future<void> saveUserInfo(String userInfo) async {
    // 保存用户信息
  };

  task() async {
    try{
      String id = await login("alice","******");
      String userInfo = await getUserInfo(id);
      await saveUserInfo(userInfo);
      //执行接下来的操作
    } catch(e){
      //错误处理
      print(e);
    }
  }
}

void example9() {
  Stream.fromFutures([
    // 1秒后返回结果
    Future.delayed(new Duration(seconds: 1), () {
      return "hello 1";
    }),
    // 抛出一个异常
    Future.delayed(new Duration(seconds: 2),(){
      throw AssertionError("Error");
    }),
    // 3秒后返回结果
    Future.delayed(new Duration(seconds: 3), () {
      return "hello 3";
    })
  ]).listen((data){
    print(data);
  }, onError: (e){
    print(e.message);
  },onDone: (){

  });
}