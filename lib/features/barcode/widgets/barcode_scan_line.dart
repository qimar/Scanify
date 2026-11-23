import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'barcode_overlay.dart';

class BarcodeScanLine extends StatelessWidget {
  final Animation<double> animation;
  final BarcodeFrameConfig config;

  const BarcodeScanLine({
    super.key,
    required this.animation,
    this.config = const BarcodeFrameConfig(),
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fh = config.frameHeight;
    final fw = config.frameWidth;
    final frameTop =
        (size.height - fh) / 2 + config.frameVerticalOffset;
    final frameLeft = (size.width - fw) / 2;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Positioned(
          top: frameTop + (fh * animation.value),
          left: frameLeft + 4,
          child: Container(
            width: fw - 8,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primaryLight,
                  AppColors.primary.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}