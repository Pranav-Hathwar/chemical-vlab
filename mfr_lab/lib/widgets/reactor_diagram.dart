import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Schematic diagram of the Mixed Flow Reactor (MFR) directly matching the MATLAB sketch.
class ReactorDiagram extends StatelessWidget {
  const ReactorDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 130,
      child: CustomPaint(
        painter: _MatlabReactorPainter(),
      ),
    );
  }
}

class _MatlabReactorPainter extends CustomPainter {
  static const Color _black = Colors.black;
  static const double _stroke = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _black
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke;

    // ── TANK (Open top rectangle) ──
    // Left: x=80, Right: x=140, Bottom: y=110, Top: y=50
    final path = Path()
      ..moveTo(80, 50)
      ..lineTo(80, 110)
      ..lineTo(140, 110)
      ..lineTo(140, 50);
    canvas.drawPath(path, linePaint);

    // ── LIQUID LEVEL ──
    final liquidPaint = Paint()
      ..color = _black
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // Draw 3 small horizontal dashes indicating liquid height
    canvas.drawLine(const Offset(105, 65), const Offset(115, 65), liquidPaint);
    canvas.drawLine(const Offset(100, 70), const Offset(120, 70), liquidPaint);
    canvas.drawLine(const Offset(105, 75), const Offset(115, 75), liquidPaint);

    // ── STIRRER ──
    // Vertical shaft down the middle
    canvas.drawLine(const Offset(110, 30), const Offset(110, 95), linePaint);
    
    // Impeller blades (crossed oval equivalent)
    final bladePath = Path()
      ..moveTo(98, 90)
      ..lineTo(122, 100)
      ..moveTo(98, 100)
      ..lineTo(122, 90);
    canvas.drawPath(bladePath, linePaint);

    // ── FEED A (from left) ──
    canvas.drawLine(const Offset(20, 45), const Offset(70, 45), linePaint); // horizontal
    canvas.drawLine(const Offset(70, 45), const Offset(70, 70), linePaint); // down
    _arrowHead(canvas, const Offset(70, 70), 90);

    // Labels for A
    _label(canvas, 'vA', 40, 26);
    _label(canvas, "C'A0", 35, 46);

    // ── FEED B (from top right) ──
    canvas.drawLine(const Offset(130, 15), const Offset(130, 48), linePaint);
    _arrowHead(canvas, const Offset(130, 48), 90);

    // Labels for B
    _label(canvas, 'vB', 140, 15);
    _label(canvas, "C'B0", 140, 33);

    // ── EXIT TRACT (from right) ──
    canvas.drawLine(const Offset(140, 85), const Offset(200, 85), linePaint);
    _arrowHead(canvas, const Offset(200, 85), 0);

    // Labels for Exit
    _label(canvas, 'vT', 170, 68);
    _label(canvas, 'CA', 170, 88);
  }

  void _arrowHead(Canvas canvas, Offset tip, double angleDeg) {
    final paint = Paint()
      ..color = _black
      ..style = PaintingStyle.fill;
    
    final radians = angleDeg * math.pi / 180.0;
    
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(radians);
    
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-8, -3)
      ..lineTo(-8, 3)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _label(Canvas canvas, String text, double x, double y) {
    // Attempting a serif font to match scientific style
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _black,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          fontFamily: 'Times New Roman', 
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
