import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/versions/v0_setstate/state/mini_provider.dart';

/// 最小 Listenable：一个会通知的计数器。
class _Counter extends ChangeNotifier {
  int value = 0;
  void increment() {
    value++;
    notifyListeners();
  }
}

void main() {
  testWidgets('of() 取到树上提供的同一个实例', (tester) async {
    final counter = _Counter();
    _Counter? got;
    await tester.pumpWidget(MiniProvider(
      notifier: counter,
      child: Builder(builder: (context) {
        got = MiniProvider.of<_Counter>(context);
        return const SizedBox();
      }),
    ));
    expect(identical(got, counter), isTrue);
  });

  testWidgets('notifyListeners 后，of() 的依赖者自动重建', (tester) async {
    final counter = _Counter();
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: MiniProvider(
        notifier: counter,
        child: Builder(builder: (context) {
          final c = MiniProvider.of<_Counter>(context);
          builds++;
          return Text('${c.value}');
        }),
      ),
    ));
    expect(builds, 1);
    expect(find.text('0'), findsOneWidget);

    counter.increment(); // 注意：没有任何 setState！
    await tester.pump();
    expect(builds, 2);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('read() 只取值不订阅：notifyListeners 后不重建', (tester) async {
    final counter = _Counter();
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: MiniProvider(
        notifier: counter,
        child: Builder(builder: (context) {
          MiniProvider.read<_Counter>(context);
          builds++;
          return const Text('static');
        }),
      ),
    ));
    expect(builds, 1);

    counter.increment();
    await tester.pump();
    expect(builds, 1); // 没订阅就不陪跑——这是 of/read 的全部区别
  });

  testWidgets('树上没有 MiniProvider 时，of()/read() 给出可读断言', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      expect(() => MiniProvider.of<_Counter>(context), throwsAssertionError);
      expect(() => MiniProvider.read<_Counter>(context), throwsAssertionError);
      return const SizedBox();
    }));
  });
}
