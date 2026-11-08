import 'package:flutter/material.dart';

/// 圆角令牌：全应用唯一的圆角取值处。
///
/// 所有可见圆角一律用超椭圆（连续圆角）渲染，禁止圆弧角；
/// 只接受 Radius 的 API（如 OutlineInputBorder）除外，取值仍从这里拿。
abstract final class AppRadius {
  /// 小元素（图标底座、区块标题图标）
  static const Radius sm = Radius.circular(10);

  /// 卡片内交互元素（设备瓦片、横幅、按钮、输入框）
  static const Radius md = Radius.circular(14);

  /// 主按钮、强调容器
  static const Radius lg = Radius.circular(16);

  /// 卡片
  static const Radius card = Radius.circular(18);

  /// 页头底部
  static const Radius header = Radius.circular(28);
}

/// 形状令牌：预构建的超椭圆 OutlinedBorder。
abstract final class AppShape {
  static const OutlinedBorder sm = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(AppRadius.sm),
  );

  static const OutlinedBorder md = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(AppRadius.md),
  );

  static const OutlinedBorder lg = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(AppRadius.lg),
  );

  static const OutlinedBorder card = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(AppRadius.card),
  );

  /// 页头（仅底部圆角）
  static const OutlinedBorder header = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(bottom: AppRadius.header),
  );

  /// 胶囊（超椭圆全半径，替代 StadiumBorder；在方形上即为正圆）
  static const OutlinedBorder pill = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );
}
