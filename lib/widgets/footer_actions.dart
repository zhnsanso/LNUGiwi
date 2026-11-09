import 'package:flutter/material.dart';

import '../ui/typography.dart';

/// 页脚操作行（WiFi 充值 / 报修热线）+ 提示文案。
class FooterActions extends StatelessWidget {
  const FooterActions({
    super.key,
    required this.onRecharge,
    required this.onSupport,
  });

  final VoidCallback onRecharge;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterAction(
                icon: Icons.account_balance_wallet_rounded,
                label: 'WiFi 充值',
                onTap: onRecharge,
              ),
              const SizedBox(width: 10),
              _FooterAction(
                icon: Icons.support_agent_rounded,
                label: '报修热线',
                onTap: onSupport,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: .7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '请先连接校园 WiFi（未认证状态）再使用。'
                  '本工具仅用于自己已购套餐的账号。',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.caption.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: .8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: scheme.primary),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
