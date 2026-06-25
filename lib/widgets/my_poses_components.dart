import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ── Direct color constants (replaces AppColors) ──
const _accent = Color(0xFF9C6FFF);
const _surface = Color(0xFF1A1A1A);
const _border = Color(0xFF2A2A2A);
const _bg = Color(0xFF0D0D0D);
const _textPrimary = Colors.white;

/// Compact "+ Add Pose" tile — transparent fill, dashed purple outline.
class AddPoseTile extends StatelessWidget {
  final VoidCallback onTap;
  const AddPoseTile({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: _accent.withValues(alpha: 0.6),
          radius: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 22, color: _accent),
              SizedBox(height: 6),
              Text(
                'Add Pose',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Processing tile — dims original photo + pulses "Processing…"
class PoseProcessingTile extends StatefulWidget {
  final File sourceImage;
  const PoseProcessingTile({required this.sourceImage, super.key});

  @override
  State<PoseProcessingTile> createState() => _PoseProcessingTileState();
}

class _PoseProcessingTileState extends State<PoseProcessingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.28,
            child: Image.file(widget.sourceImage, fit: BoxFit.cover),
          ),
          Container(color: _bg.withValues(alpha: 0.35)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_pulse),
                  child: const Text(
                    'Processing…',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Finished cutout tile — PNG on card surface with delete button.
class PoseCutoutTile extends StatelessWidget {
  final File cutoutImage;
  final VoidCallback onDelete;

  const PoseCutoutTile({
    required this.cutoutImage,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Image.file(cutoutImage, fit: BoxFit.contain),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed rounded-rect border painter.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(_dashed(path, dashLength: 6, gapLength: 5), paint);
  }

  Path _dashed(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashLength : gapLength);
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
