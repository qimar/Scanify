import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/round_icon_button.dart';
import '../scanner_type.dart';

class ScannerTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onFlashTap;
  final bool isFlashOn;
  final ScannerType scannerType;
  final VoidCallback? onGalleryTap;       // null = hidden (barcode mode)
  final bool isProcessingGallery;

  const ScannerTopBar({
    super.key,
    required this.onMenuTap,
    required this.onFlashTap,
    required this.isFlashOn,
    required this.scannerType,
    this.onGalleryTap,
    this.isProcessingGallery = false,
  });

@override
Widget build(BuildContext context) {
  final isBarcode = scannerType == ScannerType.barcode;

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
              child: Icon(
                isBarcode ? Icons.view_week_rounded : Icons.qr_code_2,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isBarcode ? 'Barcode Scanner' : 'QR Scanner',
              style: AppTextStyles.screenTitle,
            ),
          ],
        ),
        Row(
          children: [
            _GalleryTopButton(
              isProcessing: isProcessingGallery,
              onTap: onGalleryTap ?? () {},
            ),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: isFlashOn
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              iconColor: isFlashOn
                  ? AppColors.flashActive
                  : AppColors.textPrimary,
              onTap: onFlashTap,
            ),
          ],
        ),
      ],
    ),
  );
}
}

class _GalleryTopButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const _GalleryTopButton({
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgOverlay,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: isProcessing
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.textPrimary,
                ),
              )
            : const Icon(
                Icons.photo_library_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
      ),
    );
  }
}