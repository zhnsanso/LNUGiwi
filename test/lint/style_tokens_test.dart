import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 风格令牌固化：设计令牌（lib/ui/）之外禁止裸样式 API。
/// 参考 FlClash 的 test/lint/{superellipse_corners,typography}_test.dart。
void main() {
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// [allowed] 中的文件豁免（令牌定义处本身）。
  List<File> others(List<String> allowed) => dartFiles
      .where((f) => !allowed.any(f.path.replaceAll('\\', '/').endsWith))
      .toList();

  test('圆角一律使用超椭圆令牌', () {
    const banned = [
      'ClipRRect',
      'RoundedRectangleBorder',
      'StadiumBorder',
      'BorderRadius.circular(',
    ];
    final files = others(['lib/ui/shape.dart']);
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (final line in lines.where((l) => banned.any(l.contains))) {
        fail('${file.path}: 禁止的圆角 API（用 lib/ui/shape.dart 的令牌）: $line');
      }
    }
  });

  test('字号与字重一律取自 AppTextStyle 阶梯', () {
    const banned = ['fontSize:', 'FontWeight.'];
    final files = others(['lib/ui/typography.dart']);
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (final line in lines.where((l) => banned.any(l.contains))) {
        fail('${file.path}: 禁止裸字号/字重（用 lib/ui/typography.dart 的阶梯）: $line');
      }
    }
  });
}
