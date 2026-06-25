import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


/// Compact "+ Add Pose" tile — transparent fill, dashed purple outline.
/// Used as the first cell of the grid once at least one pose exists.
/// (The big solid pill button is only for the empty state.)
class AddPoseTile extends StatelessWidget {
  final VoidCallback onTap;
  const AddPoseTile({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.accent.withOpacity(0.6),
          radius: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(CupertinoIcons.add, size: 22, color: AppColors.accent),
              SizedBox(height: 6),
              Text(
                'Add Pose',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown right after a photo is picked, while the background-removal /
/// cutout step is running. Dims the original photo and pulses "Processing…".
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.28,
            child: Image.file(widget.sourceImage, fit: BoxFit.cover),
          ),
          Container(color: AppColors.background.withOpacity(0.35)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.accent,
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
                      color: AppColors.textPrimary,
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

/// A finished cutout — transparent-background PNG shown on the card surface,
/// same visual treatment as the catalog poses, with a small delete button.
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  color: Colors.black.withOpacity(0.45),
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

/// Hand-rolled dashed rounded-rect border (no extra package needed).
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

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawPath(_dashed(path, dashLength: 6, gapLength: 5), paint);
  }

  Path _dashed(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double next = distance + (draw ? dashLength : gapLength);
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
