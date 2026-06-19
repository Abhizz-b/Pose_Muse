import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pose_model.dart';

class LocalPose {
  final int id;
  final String image;
  final String category;
  final List<String> tags;
  final String difficulty;
  final String name;

  const LocalPose({
    required this.id,
    required this.image,
    required this.category,
    required this.tags,
    required this.difficulty,
    required this.name,
  });

  factory LocalPose.fromJson(Map<String, dynamic> j) => LocalPose(
    id: j['id'],
    image: j['image'],
    category: j['category'],
    tags: List<String>.from(j['tags']),
    difficulty: j['difficulty'],
    name: j['name'],
  );

  PoseModel toModel() => PoseModel(
    name: name,
    description: tags.join(', '),
    emoji: '📸',
    difficulty: difficulty,
    cameraAngle: 'Eye Level',
    imagePath: image,
  );
}

class CatalogScreen extends StatefulWidget {
  final List<PoseModel>? scannedPoses;
  final List<PoseModel>? initiallySelected;
  final int initialTabIndex;
  const CatalogScreen({super.key, this.scannedPoses, this.initiallySelected, this.initialTabIndex = 0,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PoseModel> _myPoses = [];
  List<LocalPose> _allPoses = [];
  bool _loadingMy = false;
  bool _loadingPoses = true;

  final List<LocalPose> _selectedPoses = [];

  static const Color _orange = Color(0xFF9C6FFF);
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF888888);
  static const Color _divider = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadMyPoses();
    _loadLocalPoses().then((_) {
      if (widget.initiallySelected != null) {
        setState(() {
          for (final pose in widget.initiallySelected!) {
            final match = _allPoses.where((p) => p.name == pose.name);
            if (match.isNotEmpty &&
                !_selectedPoses.any((p) => p.name == pose.name)) {
              _selectedPoses.add(match.first);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalPoses() async {
    final String data = await rootBundle.loadString('assets/poses.json');
    final List<dynamic> list = jsonDecode(data);
    setState(() {
      _allPoses = list.map((e) => LocalPose.fromJson(e)).toList();
      _loadingPoses = false;
    });
  }

  Future<void> _loadMyPoses() async {
    setState(() => _loadingMy = true);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favourites') ?? [];
    final poses = saved
        .map((s) {
          try {
            return PoseModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PoseModel>()
        .toList();
    setState(() {
      _myPoses = poses;
      _loadingMy = false;
    });
  }

  Future<void> _removePose(PoseModel pose) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favourites') ?? [];
    saved.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['name'] == pose.name;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('favourites', saved);
    await _loadMyPoses();
  }

  Future<void> _savePose(PoseModel pose) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favourites') ?? [];
    final encoded = jsonEncode(pose.toJson());
    if (!saved.contains(encoded)) {
      saved.add(encoded);
      await prefs.setStringList('favourites', saved);
      await _loadMyPoses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${pose.name} saved!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: _orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _togglePoseSelection(LocalPose pose) {
    setState(() {
      final idx = _selectedPoses.indexWhere((p) => p.id == pose.id);
      if (idx >= 0) {
        _selectedPoses.removeAt(idx);
      } else {
        _selectedPoses.add(pose);
      }
    });
  }

  bool _isPoseSelected(LocalPose pose) =>
      _selectedPoses.any((p) => p.id == pose.id);

  void _onTakePhotos() {
    if (_selectedPoses.isEmpty) return;
    Navigator.pop(context, _selectedPoses.map((p) => p.toModel()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AiPicksTab(
                    scannedPoses: widget.scannedPoses,
                    allPoses: _allPoses,
                    orange: _orange,
                    surface: _surface,
                    textSecondary: _textSecondary,
                    onScanNow: () => Navigator.pop(context),
                    onSave: _savePose,
                    selectedPoses: _selectedPoses,
                    onToggleSelect: _togglePoseSelection,
                    isPoseSelected: _isPoseSelected,
                  ),
                  _AllPosesTab(
                    poses: _allPoses,
                    loading: _loadingPoses,
                    orange: _orange,
                    surface: _surface,
                    textSecondary: _textSecondary,
                    onSave: _savePose,
                    selectedPoses: _selectedPoses,
                    onToggleSelect: _togglePoseSelection,
                    isPoseSelected: _isPoseSelected,
                  ),
                  _MyPosesTab(
                    poses: _myPoses,
                    allLocalPoses: _allPoses,
                    loading: _loadingMy,
                    orange: _orange,
                    surface: _surface,
                    textSecondary: _textSecondary,
                    onRemove: _removePose,
                    onRefresh: _loadMyPoses,
                    selectedPoses: _selectedPoses,
                    onToggleSelect: _togglePoseSelection,
                    isPoseSelected: _isPoseSelected,
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _divider),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _textPrimary,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _selectedPoses.isEmpty
                ? 'Select Poses'
                : 'Select Poses (${_selectedPoses.length})',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Clear all button — only shows when something is selected
          if (_selectedPoses.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _selectedPoses.clear()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _divider),
                ),
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 42,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.zero,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Picks'),
              ],
            ),
          ),
          const Tab(text: 'All Poses'),
          const Tab(text: 'My Poses'),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _selectedPoses.isNotEmpty;
    final count = _selectedPoses.length;
    final previewPoses = _selectedPoses.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: hasSelection ? _onTakePhotos : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelection
                    ? _orange
                    : const Color(0xFF2A2A2A),
                disabledBackgroundColor: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    color: hasSelection ? Colors.white : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Take Photos ($count)' : 'Take photos',
                    style: TextStyle(
                      color: hasSelection ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSelection ? 'Tap a pose to deselect' : 'Tap to select',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── AI Picks Tab ──
class _AiPicksTab extends StatelessWidget {
  final List<PoseModel>? scannedPoses;
  final List<LocalPose> allPoses;
  final Color orange, surface, textSecondary;
  final VoidCallback onScanNow;
  final Future<void> Function(PoseModel) onSave;
  final List<LocalPose> selectedPoses;
  final void Function(LocalPose) onToggleSelect;
  final bool Function(LocalPose) isPoseSelected;

  const _AiPicksTab({
    required this.scannedPoses,
    required this.allPoses,
    required this.orange,
    required this.surface,
    required this.textSecondary,
    required this.onScanNow,
    required this.onSave,
    required this.selectedPoses,
    required this.onToggleSelect,
    required this.isPoseSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasScanned = scannedPoses != null && scannedPoses!.isNotEmpty;
    if (!hasScanned) return _buildEmpty();

    final recommended = allPoses.take(4).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: recommended.length,
      itemBuilder: (_, i) {
        final pose = recommended[i];
        return _LocalPoseCard(
          pose: pose,
          orange: orange,
          onSave: onSave,
          isSelected: isPoseSelected(pose),
          onToggleSelect: () => onToggleSelect(pose),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Poses designed just for you',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan your scene and let PoseMuse\nfind poses for you',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onScanNow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: orange, width: 1.5),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.crop_free_rounded, color: orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Scan now',
                      style: TextStyle(
                        color: orange,
                        fontSize: 15,
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
}

// ── All Poses Tab ──
class _AllPosesTab extends StatefulWidget {
  final List<LocalPose> poses;
  final bool loading;
  final Color orange, surface, textSecondary;
  final Future<void> Function(PoseModel) onSave;
  final List<LocalPose> selectedPoses;
  final void Function(LocalPose) onToggleSelect;
  final bool Function(LocalPose) isPoseSelected;

  const _AllPosesTab({
    required this.poses,
    required this.loading,
    required this.orange,
    required this.surface,
    required this.textSecondary,
    required this.onSave,
    required this.selectedPoses,
    required this.onToggleSelect,
    required this.isPoseSelected,
  });

  @override
  State<_AllPosesTab> createState() => _AllPosesTabState();
}

class _AllPosesTabState extends State<_AllPosesTab> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'easy', 'medium', 'hard'];

  List<LocalPose> get _filtered => _filter == 'All'
      ? widget.poses
      : widget.poses
            .where((p) => p.difficulty.toLowerCase() == _filter)
            .toList();

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.orange, strokeWidth: 2),
      );
    }
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final pose = _filtered[i];
              return _LocalPoseCard(
                pose: pose,
                orange: widget.orange,
                onSave: widget.onSave,
                isSelected: widget.isPoseSelected(pose),
                onToggleSelect: () => widget.onToggleSelect(pose),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── My Poses Tab ──
class _MyPosesTab extends StatelessWidget {
  final List<PoseModel> poses;
  final List<LocalPose> allLocalPoses;
  final bool loading;
  final Color orange, surface, textSecondary;
  final Future<void> Function(PoseModel) onRemove;
  final Future<void> Function() onRefresh;
  final List<LocalPose> selectedPoses;
  final void Function(LocalPose) onToggleSelect;
  final bool Function(LocalPose) isPoseSelected;

  const _MyPosesTab({
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
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: orange, strokeWidth: 2),
      );
    }
    if (poses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, color: textSecondary, size: 44),
            const SizedBox(height: 14),
            Text(
              'No saved poses yet',
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Heart a pose to see it here',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: orange,
      backgroundColor: surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: poses.length,
        itemBuilder: (_, i) {
          final pose = poses[i];
          final matched = allLocalPoses.firstWhere(
            (l) => l.name == pose.name,
            orElse: () => allLocalPoses.isNotEmpty
                ? allLocalPoses[i % allLocalPoses.length]
                : LocalPose(
                    id: 0,
                    image: 'assets/poses/1.png',
                    category: '',
                    tags: [],
                    difficulty: 'easy',
                    name: pose.name,
                  ),
          );
          return _LocalPoseCard(
            pose: matched,
            orange: orange,
            onSave: (_) async {},
            isSelected: isPoseSelected(matched),
            onToggleSelect: () => onToggleSelect(matched),
            onLongPress: () async {
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
                      child: Text('Remove', style: TextStyle(color: orange)),
                    ),
                  ],
                ),
              );
              if (remove == true) onRemove(pose);
            },
          );
        },
      ),
    );
  }
}

// ── Pose Card — Glow effect on select, NO SS badge, NO name, NO difficulty ──
class _LocalPoseCard extends StatelessWidget {
  final LocalPose pose;
  final Color orange;
  final bool isSelected;
  final Future<void> Function(PoseModel) onSave;
  final VoidCallback onToggleSelect;
  final Future<void> Function()? onLongPress;

  const _LocalPoseCard({
    required this.pose,
    required this.orange,
    required this.onSave,
    required this.isSelected,
    required this.onToggleSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleSelect,
      onLongPress: onLongPress != null ? () => onLongPress!() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // subtle glow when selected
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Pose image
              Image.asset(
                pose.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1C1C1C),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white38,
                      size: 32,
                    ),
                  ),
                ),
              ),

              // Subtle vignette
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.25),
                      ],
                      stops: const [0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // ✅ Checkmark only — no SS badge
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
