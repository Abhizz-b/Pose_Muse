import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Photos that have been picked and are currently going through the
  /// background-removal / cutout pipeline. The parent screen owns this
  /// list: add a file here as soon as it's picked, remove it (and push
  /// the finished result into `poses`) once the cutout is ready.
  final List<File> processingPoses;

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
    this.processingPoses = const [],
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

    final allTabEmpty = widget.poses.isEmpty && widget.processingPoses.isEmpty;

    return Column(
      children: [
        _buildSubTabs(),
        const SizedBox(height: 4),
        Expanded(
          child: _subTabIndex == 2
              ? _buildAlbumsPlaceholder()
              : (allTabEmpty && _subTabIndex == 0)
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

    // The Add tile + in-flight processing cards only live in the "All" tab.
    final showAddTile = _subTabIndex == 0;
    final processing = _subTabIndex == 0
        ? widget.processingPoses
        : const <File>[];
    final addOffset = showAddTile ? 1 : 0;
    final totalItems = addOffset + processing.length + poses.length;

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
        itemCount: totalItems,
        itemBuilder: (_, i) {
          if (showAddTile && i == 0) {
            return _AddPoseTile(orange: widget.orange, onTap: widget.onAddPose);
          }

          final processingIndex = i - addOffset;
          if (processingIndex < processing.length) {
            return _ProcessingPoseCard(
              imageFile: processing[processingIndex],
              orange: widget.orange,
            );
          }

          final pose = poses[processingIndex - processing.length];
          // 2-second hold (not the default ~500ms long-press) triggers the
          // remove confirmation. _MyPoseCard itself has no gesture of its
          // own anymore — this wrapper owns press feedback + the timer.
          return _HoldToRemove(
            onHoldComplete: () => _confirmRemove(context, pose),
            child: _MyPoseCard(
              pose: pose,
              orange: widget.orange,
              isFavourite: _isFavourite(pose),
              onToggleFavourite: () {},
            ),
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

  /// Minimal custom remove-confirmation card (replaces the old AlertDialog).
  Future<void> _confirmRemove(BuildContext context, PoseModel pose) async {
    final remove = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: widget.orange,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove this pose?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This will delete it from My Poses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF333333)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.orange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (remove == true) widget.onRemove(pose);
  }
}

/// Renders a pose thumbnail whether it's a bundled catalog asset
/// (e.g. 'assets/poses/warrior.png') or a local file from the user's
/// own upload (an absolute path starting with '/', saved after cutout).
Widget _buildPoseThumbnail(String? path) {
  if (path == null || path.isEmpty) {
    return const Icon(
      Icons.image_not_supported,
      color: Colors.white38,
      size: 32,
    );
  }
  final isLocalFile = path.startsWith('/');
  if (isLocalFile) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.image_not_supported,
        color: Colors.white38,
        size: 32,
      ),
    );
  }
  return Image.asset(
    path,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) =>
        const Icon(Icons.image_not_supported, color: Colors.white38, size: 32),
  );
}

class _MyPoseCard extends StatelessWidget {
  final PoseModel pose;
  final Color orange;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;

  const _MyPoseCard({
    required this.pose,
    required this.orange,
    required this.isFavourite,
    required this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              child: _buildPoseThumbnail(pose.imagePath),
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
    );
  }
}

/// Compact "+ Add Pose" grid tile — transparent/dashed, sits first in the
/// grid once at least one pose (saved or processing) exists. The big solid
/// pill button in `_buildEmptyState` is only for the fully-empty state.
class _AddPoseTile extends StatelessWidget {
  final Color orange;
  final VoidCallback onTap;

  const _AddPoseTile({required this.orange, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderContainer(
        color: orange,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: orange, size: 24),
              const SizedBox(height: 6),
              Text(
                'Add Pose',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for a photo that's been picked but hasn't finished the
/// background-removal / cutout step yet. Dims the source photo and pulses
/// "Processing…" until the parent moves it out of `processingPoses`.
class _ProcessingPoseCard extends StatefulWidget {
  final File imageFile;
  final Color orange;

  const _ProcessingPoseCard({required this.imageFile, required this.orange});

  @override
  State<_ProcessingPoseCard> createState() => _ProcessingPoseCardState();
}

class _ProcessingPoseCardState extends State<_ProcessingPoseCard>
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.3,
              child: Image.file(widget.imageFile, fit: BoxFit.cover),
            ),
            Container(color: Colors.black.withOpacity(0.35)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: widget.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.45,
                      end: 1.0,
                    ).animate(_pulse),
                    child: const Text(
                      'Processing…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a child with custom-duration press-and-hold detection (default
/// 2 seconds) instead of Flutter's built-in ~500ms long-press. Scales the
/// child down slightly while held for visual feedback, fires a light
/// haptic + [onHoldComplete] once the duration is reached.
class _HoldToRemove extends StatefulWidget {
  final Widget child;
  final VoidCallback onHoldComplete;
  final Duration duration;

  const _HoldToRemove({
    required this.child,
    required this.onHoldComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<_HoldToRemove> createState() => _HoldToRemoveState();
}

class _HoldToRemoveState extends State<_HoldToRemove> {
  Timer? _timer;
  bool _pressed = false;

  void _start() {
    setState(() => _pressed = true);
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _pressed = false);
      HapticFeedback.mediumImpact();
      widget.onHoldComplete();
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
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
