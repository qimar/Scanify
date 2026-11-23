import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'qr_overlay.dart';

/// Renders the animated blue scan line that sweeps up and down
/// within the scan frame.
class ScanLine extends StatelessWidget {
  final Animation<double> animation;
  final ScanFrameConfig config;

  const ScanLine({
    super.key,
    required this.animation,
    this.config = const ScanFrameConfig(),
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = config.frameSize;
    final frameTop =
        (size.height - frameSize) / 2 + config.frameVerticalOffset;
    final frameLeft = (size.width - frameSize) / 2;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Positioned(
          top: frameTop + (frameSize * animation.value),
          left: frameLeft + 4,
          child: Container(
            width: frameSize - 8,
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
