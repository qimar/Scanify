import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ResultActionButtons extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback? onPrimaryAction;
  final IconData? primaryIcon;
  final String? primaryLabel;
  final Color? primaryColor;

  const ResultActionButtons({
    super.key,
    required this.onCopy,
    this.onPrimaryAction,
    this.primaryIcon,
    this.primaryLabel,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrimary = onPrimaryAction != null && primaryIcon != null;

    return Row(
      children: [
        // Copy always shown — full width if no primary action, half if there is
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_rounded,
            label: 'Copy',
            color: AppColors.bgSurface,
            onTap: onCopy,
          ),
        ),
        if (hasPrimary) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: primaryIcon!,
              label: primaryLabel ?? 'Open',
              color: primaryColor ?? AppColors.primary,
              onTap: onPrimaryAction!,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}