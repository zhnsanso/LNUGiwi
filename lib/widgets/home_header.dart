import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../ui/shape.dart';
import '../ui/theme.dart';
import '../ui/typography.dart';

/// 页头：品牌渐变 + 标题 + 状态胶囊（含在线时长常驻行）。
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.status, this.onlineDuration});

  final OnlineStatus? status;
  final String? onlineDuration;

  @override
  Widget build(BuildContext context) {
    final (String label, Color dotColor) = switch (status) {
      OnlineStatus.online => ('已认证', const Color(0xFF4ADE80)),
      OnlineStatus.offline => ('未认证', const Color(0xFFFBBF24)),
      OnlineStatus.unknown => ('状态未知', const Color(0xFFE2E8F0)),
      null => ('未检测', const Color(0xFFE2E8F0)),
    };
    return Container(
      width: double.infinity,
      decoration: const ShapeDecoration(
        gradient: kBrandGradient,
        shape: AppShape.header,
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: kBrandInk.withValues(alpha: .14),
              shape: AppShape.md,
            ),
            child: const Icon(Icons.wifi_rounded, color: kBrandInk, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GiWiFi 一键认证', style: AppTextStyle.titleXL),
                const SizedBox(height: 3),
                Text(
                  '校园网终端 · 一键切换 · 极速认证',
                  style: AppTextStyle.footnote.copyWith(color: kBrandInkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: ShapeDecoration(
              color: kBrandInk.withValues(alpha: .14),
              shape: AppShape.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyle.footnoteEmphasized),
                    if (onlineDuration != null)
                      Text(
                        '已在线 $onlineDuration',
                        style: AppTextStyle.chip.copyWith(
                          color: kBrandInkSoft,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
