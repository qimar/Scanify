import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/round_icon_button.dart';

class BarcodeTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onFlashTap;
  final bool isFlashOn;

  const BarcodeTopBar({
    super.key,
    required this.onMenuTap,
    required this.onFlashTap,
    required this.isFlashOn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(
            icon: Icons.menu_rounded,
            onTap: onMenuTap,
          ),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.view_week_rounded,
                    color: AppColors.textPrimary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Barcode Scanner', style: AppTextStyles.screenTitle),
            ],
          ),
          RoundIconButton(
            icon: isFlashOn
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            iconColor:
                isFlashOn ? AppColors.flashActive : AppColors.textPrimary,
            onTap: onFlashTap,
          ),
        ],
      ),
    );
  }
}