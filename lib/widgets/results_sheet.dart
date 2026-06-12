import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/detection_result.dart';
import '../models/pose_model.dart';

class ResultsSheet extends StatefulWidget {
  final DetectionResult result;
  final Function(PoseModel) onSavePose;

  static const _purple = Color(0xFF9C6FFF);

  const ResultsSheet({
    super.key,
    required this.result,
    required this.onSavePose,
  });

  @override
  State<ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends State<ResultsSheet> {
  static const _purple = Color(0xFF9C6FFF);
  static const _bg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.93,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _purple.withOpacity(0.15), width: 1),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Container(
                  width: 36,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.result.environment,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.result.poses.isEmpty
                                    ? 'Generating poses...'
                                    : '${widget.result.poses.length} poses recommended',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Confidence badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _purple.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${(widget.result.confidence * 100).toInt()}%',
                                style: const TextStyle(
                                  color: _purple,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'match',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Info chips
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.light_mode_outlined,
                          label: widget.result.lighting,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.mood_outlined,
                          label: widget.result.mood,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'RECOMMENDED POSES',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Loading or pose cards
                    if (widget.result.poses.isEmpty)
                      _LoadingPoses()
                    else
                      ...widget.result.poses.map(
                        (pose) => _PoseCard(
                          pose: pose,
                          onSave: () {
                            HapticFeedback.lightImpact();
                            widget.onSavePose(pose);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingPoses extends StatefulWidget {
  @override
  State<_LoadingPoses> createState() => _LoadingPosesState();
}

class _LoadingPosesState extends State<_LoadingPoses>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF9C6FFF),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AI generating pose...',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  static const _purple = Color(0xFF9C6FFF);

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _purple),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PoseCard extends StatefulWidget {
  final PoseModel pose;
  final VoidCallback onSave;

  const _PoseCard({required this.pose, required this.onSave});

  @override
  State<_PoseCard> createState() => _PoseCardState();
}

class _PoseCardState extends State<_PoseCard>
    with SingleTickerProviderStateMixin {
  bool _saved = false;
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  static const _purple = Color(0xFF9C6FFF);

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Color get _diffColor {
    switch (widget.pose.difficulty) {
      case 'Hard':
        return const Color(0xFFFF6B6B);
      case 'Medium':
        return const Color(0xFFFFB347);
      default:
        return const Color(0xFF6BCB77);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _saved
              ? _purple.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emoji
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.pose.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pose.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.pose.description,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _diffColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.pose.difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          color: _diffColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 11,
                      color: Colors.white24,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.pose.cameraAngle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Heart button
          GestureDetector(
            onTap: () {
              setState(() => _saved = !_saved);
              _heartController.forward(from: 0);
              if (_saved) widget.onSave();
            },
            child: ScaleTransition(
              scale: _heartScale,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _saved
                      ? _purple.withOpacity(0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _saved ? _purple : Colors.white24,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
