import 'package:flutter/material.dart';

/// 字号阶梯：全应用唯一的字号/字重取值处。
///
/// 阶梯刻度参考 Apple Dynamic Type 的默认档位裁剪；
/// `lib/` 其余文件禁止出现裸 `fontSize:` / `FontWeight.`
/// （`test/lint/style_tokens_test.dart` 强制）。
/// 颜色随场景用 `copyWith` 叠加，不进阶梯。
abstract final class AppTextStyle {
  /// 页头大标题
  static const TextStyle titleXL = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: .2,
  );

  /// 区块标题 / 按钮文字
  static const TextStyle title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// 正文 / 开关标签
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// 强调正文（结果横幅）
  static const TextStyle callout = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// 对话框正文
  static const TextStyle calloutNormal = TextStyle(fontSize: 13.5, height: 1.5);

  /// 脚注（副标题、日志时间、空态）
  static const TextStyle footnote = TextStyle(fontSize: 12.5);

  /// 脚注强调（状态标签、设备瓦片文字）
  static const TextStyle footnoteEmphasized = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  /// 说明文字（表单提示、页脚）
  static const TextStyle caption = TextStyle(fontSize: 11.5);

  /// 芯片文字
  static const TextStyle chip = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}
