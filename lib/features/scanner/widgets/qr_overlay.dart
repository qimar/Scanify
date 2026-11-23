import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'corner_brackets.dart';

/// Configuration for the scan frame dimensions.
/// Change [frameSize] or [frameVerticalOffset] to resize/reposition the frame.
class ScanFrameConfig {
  final double frameSize;
  final double frameVerticalOffset; // negative = shift up from center

  const ScanFrameConfig({
    this.frameSize = 260,
    this.frameVerticalOffset = -40,
  });
}

/// Renders the dark overlay around the transparent scan area,
/// plus the corner brackets on top.
class QrOverlay extends StatelessWidget {
  final ScanFrameConfig config;

  const QrOverlay({
    super.key,
    this.config = const ScanFrameConfig(),
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = config.frameSize;
    final frameTop =
        (size.height - frameSize) / 2 + config.frameVerticalOffset;
    final frameLeft = (size.width - frameSize) / 2;

    return Stack(
      children: [
        // Top panel
        Positioned(
          top: 0, left: 0, right: 0,
          height: frameTop,
          child: _DarkPane(),
        ),
        // Bottom panel
        Positioned(
          top: frameTop + frameSize,
          left: 0, right: 0, bottom: 0,
          child: _DarkPane(),
        ),
        // Left panel
        Positioned(
          top: frameTop, left: 0,
          width: frameLeft, height: frameSize,
          child: _DarkPane(),
        ),
        // Right panel
        Positioned(
          top: frameTop, right: 0,
          width: frameLeft, height: frameSize,
          child: _DarkPane(),
        ),
        // Corner brackets
        Positioned(
          top: frameTop,
          left: frameLeft,
          child: CornerBrackets(size: frameSize),
        ),
      ],
    );
  }
}

class _DarkPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(color: AppColors.bgOverlay);
}
