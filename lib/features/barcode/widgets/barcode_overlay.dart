import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Frame config for the barcode scan area.
/// Barcodes are wide and short, so the frame is landscape-ratio.
class BarcodeFrameConfig {
  final double frameWidth;
  final double frameHeight;
  final double frameVerticalOffset; // negative = shift up from center

  const BarcodeFrameConfig({
    this.frameWidth = 300,
    this.frameHeight = 130,
    this.frameVerticalOffset = -40,
  });
}

class BarcodeOverlay extends StatelessWidget {
  final BarcodeFrameConfig config;

  const BarcodeOverlay({
    super.key,
    this.config = const BarcodeFrameConfig(),
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fw = config.frameWidth;
    final fh = config.frameHeight;
    final frameTop =
        (size.height - fh) / 2 + config.frameVerticalOffset;
    final frameLeft = (size.width - fw) / 2;

    return Stack(
      children: [
        // Top
        Positioned(
            top: 0, left: 0, right: 0,
            height: frameTop,
            child: _DarkPane()),
        // Bottom
        Positioned(
            top: frameTop + fh,
            left: 0, right: 0, bottom: 0,
            child: _DarkPane()),
        // Left
        Positioned(
            top: frameTop, left: 0,
            width: frameLeft, height: fh,
            child: _DarkPane()),
        // Right
        Positioned(
            top: frameTop, right: 0,
            width: frameLeft, height: fh,
            child: _DarkPane()),
        // Corner brackets
        Positioned(
          top: frameTop,
          left: frameLeft,
          child: _BarcodeCornerBrackets(width: fw, height: fh),
        ),
      ],
    );
  }
}

class _DarkPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.black.withOpacity(0.65));
}

class _BarcodeCornerBrackets extends StatelessWidget {
  final double width;
  final double height;

  const _BarcodeCornerBrackets(
      {required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BarcodeCornerPainter(),
      ),
    );
  }
}

class _BarcodeCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Shorter arm for the tall sides, longer for wide sides
    const armW = 24.0; // horizontal arm
    const armH = 18.0; // vertical arm
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(0, armH), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(armW, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - armW, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, armH), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - armH), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(armW, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w - armW, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - armH), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}