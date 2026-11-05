import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // ProviderScope 是 Riverpod 的容器，必须包在 App 最外层。
  // 少了它，任何 provider 的读取都会抛 "No ProviderScope found"。
  runApp(const ProviderScope(child: RiverpodLabApp()));
}
