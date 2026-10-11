/// 串行执行异步修改，≈ 一个只允许一项任务运行的串行 DispatchQueue。
/// 等待初始化并不等于互斥；把“读 → 改 → 保存”整个临界区排队才不会丢更新。
class SerialTaskQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    // 调用方仍收到原始错误；队尾吸收错误，让下一项可以继续。
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
