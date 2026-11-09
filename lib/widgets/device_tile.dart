import 'package:flutter/material.dart';

import '../models/device_profile.dart';
import '../ui/shape.dart';
import '../ui/typography.dart';

/// 设备预设 id -> 图标。
IconData deviceIcon(String id) => switch (id) {
      'pc' => Icons.computer_rounded,
      'android_phone' => Icons.smartphone_rounded,
      'iphone' => Icons.phone_iphone_rounded,
      'ipad' => Icons.tablet_mac_rounded,
      'android_tablet' => Icons.tablet_android_rounded,
      'custom' => Icons.tune_rounded,
      _ => Icons.devices_rounded,
    };

/// 设备类型选择瓦片（三列网格中的单个选项）。
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.width,
    required this.profile,
    required this.selected,
    required this.onSelect,
  });

  final double width;
  final DeviceProfile profile;
  final bool selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Material(
        color: selected
            ? scheme.primary
            : scheme.surfaceContainerHighest.withValues(alpha: .45),
        animationDuration: const Duration(milliseconds: 160),
        shape: AppShape.md,
        child: InkWell(
          customBorder: AppShape.md,
          onTap: () => onSelect(profile.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 86,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: const BorderRadius.all(AppRadius.md),
                side: BorderSide(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: .55),
                  width: selected ? 1.6 : 1,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(deviceIcon(profile.id), size: 24, color: fg),
                const SizedBox(height: 7),
                Text(
                  profile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.footnoteEmphasized.copyWith(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
