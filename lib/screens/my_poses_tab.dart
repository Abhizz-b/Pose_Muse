import 'package:flutter/material.dart';
import '../models/pose_model.dart';
import '../models/local_pose.dart';

class MyPosesTab extends StatefulWidget {
  final List<PoseModel> poses;
  final List<LocalPose> allLocalPoses;
  final bool loading;
  final Color orange, surface, textSecondary;
  final Future<void> Function(PoseModel) onRemove;
  final Future<void> Function() onRefresh;
  final List<LocalPose> selectedPoses;
  final void Function(LocalPose) onToggleSelect;
  final bool Function(LocalPose) isPoseSelected;
  final VoidCallback onAddPose;

  const MyPosesTab({
    required this.poses,
    required this.allLocalPoses,
    required this.loading,
    required this.orange,
    required this.surface,
    required this.textSecondary,
    required this.onRemove,
    required this.onRefresh,
    required this.selectedPoses,
    required this.onToggleSelect,
    required this.isPoseSelected,
    required this.onAddPose,
  });

  @override
  State<MyPosesTab> createState() => _MyPosesTabState();
}

class _MyPosesTabState extends State<MyPosesTab> {
  int _subTabIndex = 0;
  final List<String> _subTabs = ['All', 'Favourites', 'Albums'];

  bool _isFavourite(PoseModel pose) => false;

  List<PoseModel> get _filteredPoses {
    switch (_subTabIndex) {
      case 1:
        return widget.poses.where(_isFavourite).toList();
      case 2:
        return [];
      default:
        return widget.poses;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.orange, strokeWidth: 2),
      );
    }

    return Column(
      children: [
        _buildSubTabs(),
        const SizedBox(height: 4),
        Expanded(
          child: _subTabIndex == 2
              ? _buildAlbumsPlaceholder()
              : (widget.poses.isEmpty && _subTabIndex == 0)
              ? _buildEmptyState()
              : _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildSubTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(_subTabs.length, (i) {
            final selected = i == _subTabIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _subTabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? widget.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _subTabs[i],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF555555),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final poses = _filteredPoses;

    if (poses.isEmpty && _subTabIndex == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                color: widget.orange,
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'No favourites yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart on any pose\nto save it here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: widget.orange,
      backgroundColor: widget.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3 / 4,
        ),
        itemCount: poses.length,
        itemBuilder: (_, i) {
          final pose = poses[i];
          return _MyPoseCard(
            pose: pose,
            orange: widget.orange,
            isFavourite: _isFavourite(pose),
            onToggleFavourite: () {},
            onLongPress: () => _confirmRemove(context, pose),
          );
        },
      ),
    );
  }

  Widget _buildAlbumsPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, color: widget.textSecondary, size: 44),
            const SizedBox(height: 14),
            const Text(
              'No albums yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Group your poses into albums',
              style: TextStyle(color: widget.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: widget.orange,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No saved poses yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF3F3F3),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a photo to create your own\npose cutout',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: widget.onAddPose,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.orange,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Add Pose',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, PoseModel pose) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Remove pose?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "${pose.name}"?',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: widget.orange)),
          ),
        ],
      ),
    );
    if (remove == true) widget.onRemove(pose);
  }
}

class _MyPoseCard extends StatelessWidget {
  final PoseModel pose;
  final Color orange;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback onLongPress;

  const _MyPoseCard({
    required this.pose,
    required this.orange,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Image.asset(
                  pose.imagePath ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported,
                    color: Colors.white38,
                    size: 32,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 9,
              right: 9,
              child: GestureDetector(
                onTap: onToggleFavourite,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0x77000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavourite ? orange : Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  final Color color;
  final Widget child;
  const DottedBorderContainer({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
