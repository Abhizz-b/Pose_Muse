import 'package:flutter/material.dart';

class ScanOverlay extends StatefulWidget {
  final bool isScanning;
  const ScanOverlay({super.key, required this.isScanning});
  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanPainter(
            isScanning: widget.isScanning,
            progress: _animation.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _ScanPainter extends CustomPainter {
  final bool isScanning;
  final double progress;
  final Color purple = const Color(0xFF7C4DFF);

  _ScanPainter({required this.isScanning, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = purple.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double boxSize = size.width * 0.75;
    final double left = (size.width - boxSize) / 2;
    final double top = (size.height - boxSize) / 2 - 40;
    final double c = 30;

    canvas.drawLine(Offset(left, top), Offset(left + c, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + c), paint);
    canvas.drawLine(Offset(left + boxSize, top), Offset(left + boxSize - c, top), paint);
    canvas.drawLine(Offset(left + boxSize, top), Offset(left + boxSize, top + c), paint);
    canvas.drawLine(Offset(left, top + boxSize), Offset(left + c, top + boxSize), paint);
    canvas.drawLine(Offset(left, top + boxSize), Offset(left, top + boxSize - c), paint);
    canvas.drawLine(Offset(left + boxSize, top + boxSize), Offset(left + boxSize - c, top + boxSize), paint);
    canvas.drawLine(Offset(left + boxSize, top + boxSize), Offset(left + boxSize, top + boxSize - c), paint);

    if (isScanning) {
      final scanY = top + (boxSize * progress);
      final scanPaint = Paint()
        ..color = purple.withOpacity(0.8)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(left, scanY), Offset(left + boxSize, scanY), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => true;
}
