import 'package:flutter/material.dart';

import '../ui/shape.dart';
import '../ui/theme.dart';

/// 一键认证主按钮：渐变底、认证中变灰并转圈、认证中点击为停止。
class PrimaryAuthButton extends StatelessWidget {
  const PrimaryAuthButton({
    super.key,
    required this.checking,
    required this.busy,
    required this.onPressed,
  });

  final bool checking;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRSuperellipse(
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: checking
              ? LinearGradient(
                  colors: [
                    scheme.surfaceContainerHighest,
                    scheme.surfaceContainerHighest,
                  ],
                )
              : kBrandGradient,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: kBrandInk,
            disabledForegroundColor:
                checking ? scheme.onSurfaceVariant : kBrandInk,
            elevation: 0,
            minimumSize: const Size.fromHeight(56),
            shape: const RoundedSuperellipseBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBrandInk,
                  ),
                )
              else
                const Icon(Icons.login_rounded, size: 20),
              const SizedBox(width: 8),
              Text(busy ? '停止认证' : '一键认证'),
            ],
          ),
        ),
      ),
    );
  }
}
