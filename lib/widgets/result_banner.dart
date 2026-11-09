import 'package:flutter/material.dart';

import '../ui/shape.dart';
import '../ui/typography.dart';

/// 认证结果横幅：ok=成功绿 / 失败红，深浅色各有配色；
/// ok+message 变化时通过 ValueKey 触发切换动画。
class ResultBanner extends StatelessWidget {
  const ResultBanner({super.key, required this.ok, required this.message});

  final bool ok;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? (ok ? const Color(0xFF14331F) : const Color(0xFF3A1B1E))
        : (ok ? const Color(0xFFE8F8EF) : const Color(0xFFFDECEC));
    final fg = isDark
        ? (ok ? const Color(0xFF7BE3AB) : const Color(0xFFFFA6A0))
        : (ok ? const Color(0xFF14794A) : const Color(0xFFB3261E));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: Container(
        key: ValueKey<String>('$ok:$message'),
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(AppRadius.md),
            side: BorderSide(color: fg.withValues(alpha: .35)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyle.callout.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
