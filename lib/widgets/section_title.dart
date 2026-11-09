import 'package:flutter/material.dart';

import '../ui/shape.dart';
import '../ui/typography.dart';

/// 区块标题：图标底座 + 标题 + 副标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.icon, this.title, this.subtitle, {super.key});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: ShapeDecoration(
            color: scheme.primary.withValues(alpha: .10),
            shape: AppShape.sm,
          ),
          child: Icon(icon, size: 19, color: scheme.primary),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyle.title),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: AppTextStyle.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
