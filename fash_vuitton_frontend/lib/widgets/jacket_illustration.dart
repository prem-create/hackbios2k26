import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class JacketIllustration extends StatelessWidget {
  final double size;

  const JacketIllustration({
    super.key,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _JacketPainter(),
      ),
    );
  }
}

class _JacketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final bgRadius = size.width * 0.44;

    // Background Yellow Disk
    final bgPaint = Paint()
      ..color = AppColors.yellow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, bgRadius, bgPaint);

    final w = size.width;
    final h = size.height;

    // Jacket Main Body Fill
    final jacketPaint = Paint()
      ..color = const Color(0xFFFF5A4F) // Coral Jacket
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.navy.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Main coat body path
    final coatPath = Path()
      ..moveTo(w * 0.32, h * 0.28) // top left collar
      ..lineTo(w * 0.68, h * 0.28) // top right collar
      ..lineTo(w * 0.76, h * 0.42) // shoulder right
      ..lineTo(w * 0.76, h * 0.88) // bottom right
      ..lineTo(w * 0.24, h * 0.88) // bottom left
      ..lineTo(w * 0.24, h * 0.42) // shoulder left
      ..close();

    canvas.drawPath(coatPath, jacketPaint);

    // Left Sleeve
    final leftSleeve = Path()
      ..moveTo(w * 0.24, h * 0.30)
      ..lineTo(w * 0.10, h * 0.40)
      ..lineTo(w * 0.18, h * 0.72)
      ..lineTo(w * 0.26, h * 0.68)
      ..close();
    canvas.drawPath(leftSleeve, jacketPaint);

    // Right Sleeve
    final rightSleeve = Path()
      ..moveTo(w * 0.76, h * 0.30)
      ..lineTo(w * 0.90, h * 0.40)
      ..lineTo(w * 0.82, h * 0.72)
      ..lineTo(w * 0.74, h * 0.68)
      ..close();
    canvas.drawPath(rightSleeve, jacketPaint);

    // Outlines
    canvas.drawPath(coatPath, outlinePaint);
    canvas.drawPath(leftSleeve, outlinePaint);
    canvas.drawPath(rightSleeve, outlinePaint);

    // Center placket line
    canvas.drawLine(
      Offset(w * 0.5, h * 0.28),
      Offset(w * 0.5, h * 0.88),
      outlinePaint,
    );

    // Collar flaps
    final collarLeft = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..lineTo(w * 0.44, h * 0.38)
      ..lineTo(w * 0.50, h * 0.28);
    final collarRight = Path()
      ..moveTo(w * 0.68, h * 0.28)
      ..lineTo(w * 0.56, h * 0.38)
      ..lineTo(w * 0.50, h * 0.28);

    canvas.drawPath(collarLeft, outlinePaint);
    canvas.drawPath(collarRight, outlinePaint);

    // Pockets
    final pocketPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final leftPocket = Rect.fromLTWH(w * 0.29, h * 0.64, w * 0.16, h * 0.16);
    final rightPocket = Rect.fromLTWH(w * 0.55, h * 0.64, w * 0.16, h * 0.16);

    canvas.drawRect(leftPocket, pocketPaint);
    canvas.drawRect(leftPocket, outlinePaint);
    canvas.drawRect(rightPocket, pocketPaint);
    canvas.drawRect(rightPocket, outlinePaint);

    // Buttons
    final buttonPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.5, h * 0.40), 4, buttonPaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.40), 4, outlinePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), 4, buttonPaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), 4, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
