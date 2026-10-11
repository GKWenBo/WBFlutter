import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('跨业务模块 import/export 只通过公开入口引用', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
        continue;
      }
      final current = file.path.split('/');
      final featureIndex = current.indexOf('features');
      final owner = featureIndex < 0 ? null : current[featureIndex + 1];
      for (final match in RegExp(
        r'''(?:import|export)\s+['"]([^'"]+)['"]''',
      ).allMatches(file.readAsStringSync())) {
        final import = match.group(1)!;
        final target = import.startsWith('package:wan_android/')
            ? File(
                'lib/${import.substring('package:wan_android/'.length)}',
              ).absolute.uri
            : file.absolute.uri.resolve(import);
        final parts = target.pathSegments;
        final index = parts.indexOf('features');
        if (index < 0 || parts[index + 1] == owner) continue;
        if (parts.length != index + 3 ||
            !{'api.dart', 'models.dart', 'ui.dart'}.contains(parts.last)) {
          violations.add('${file.path}: $import');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
  test('公开入口限定导出，导出图不存在循环', () {
    final exports = <Uri, List<Uri>>{};
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
        continue;
      }
      final edges = <Uri>[];
      for (final match in RegExp(
        r'''export\s+['"]([^'"]+)['"]([^;]*);''',
      ).allMatches(file.readAsStringSync())) {
        final path = match.group(1)!;
        if (file.path.contains('/features/') &&
            {
              'api.dart',
              'models.dart',
              'ui.dart',
            }.contains(file.uri.pathSegments.last)) {
          expect(match.group(2), contains('show '), reason: file.path);
        }
        if (!path.startsWith('package:') && !path.startsWith('dart:')) {
          edges.add(file.absolute.uri.resolve(path));
        }
      }
      exports[file.absolute.uri] = edges;
    }
    final visited = <Uri>{};
    final active = <Uri>{};
    bool hasCycle(Uri file) {
      if (active.contains(file)) return true;
      if (!visited.add(file)) return false;
      active.add(file);
      for (final target in exports[file] ?? <Uri>[]) {
        if (hasCycle(target)) return true;
      }
      active.remove(file);
      return false;
    }

    expect(exports.keys.any(hasCycle), isFalse);
  });
}
