import 'dart:convert';
import 'dart:ui';
import '../models/scan_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pose_model.dart';
import 'my_poses_tab.dart';
import '../models/local_pose.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/background_removal_service.dart'; // apna actual path daal do
import 'settings_screen.dart';

class CatalogScreen extends StatefulWidget {
  final ScanResult? scanResult;
  final List<PoseModel>? initiallySelected;
  final int initialTabIndex;
  const CatalogScreen({
    super.key,
    this.scanResult,
    this.initiallySelected,
    this.initialTabIndex = 0,
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
  final List<File> _processingPoses = [];
  final List<PoseModel> _selectedMyPoses = [];

  // Photos picked from the gallery that are currently going through
  // background removal — shown as "Processing…" tiles inside My Poses.

  bool get _isDark => themeNotifier.value != ThemeMode.light;
  Color get _bg => _isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F7);
  Color get _surface =>
      _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF111111);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF888888) : const Color(0xFF666666);
  Color get _divider =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  // ✅ NEW — theme-aware colors for the disabled "Take photos" bottom bar
  Color get _disabledBg =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  Color get _disabledText => _isDark ? Colors.white38 : const Color(0xFF9A9A9A);
  static const Color _orange = Color(0xFF9C6FFF);

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
    themeNotifier.addListener(() {
      if (mounted) setState(() {});
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

  // ── Add Pose flow: pick from gallery → remove.bg cutout → persist ──
  Future<void> _handleAddPose() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    final file = File(picked.path);

    setState(() => _processingPoses.add(file));

    try {
      final cutout = await BackgroundRemovalService.removeBackground(file);
      final pose = PoseModel(
        name: 'My pose ${DateTime.now().millisecondsSinceEpoch}',
        imagePath: cutout.path,
        description: '',
        difficulty: 'easy',
        cameraAngle: '',
        emoji: '',
      );
      await _savePose(pose); // persists + reloads _myPoses + shows snackbar
    } catch (e) {
      debugPrint('❌ BG removal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      setState(() => _processingPoses.remove(file));
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
    debugPrint(
      'catalog: ${_selectedPoses.length}, myPoses: ${_selectedMyPoses.length}',
    );
    if (_selectedPoses.isEmpty && _selectedMyPoses.isEmpty) return;
    final fromCatalog = _selectedPoses.map((p) => p.toModel()).toList();
    final fromMyPoses = List<PoseModel>.from(_selectedMyPoses);
    debugPrint('popping with ${[...fromCatalog, ...fromMyPoses].length} poses');
    Navigator.pop(context, [...fromCatalog, ...fromMyPoses]);
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
                    scanResult: widget.scanResult,
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
                  MyPosesTab(
                    onToggleMyPose: (pose) {
                      setState(() {
                        final idx = _selectedMyPoses.indexWhere(
                          (p) => p.name == pose.name,
                        );
                        if (idx >= 0)
                          _selectedMyPoses.removeAt(idx);
                        else
                          _selectedMyPoses.add(pose);
                      });
                    },
                    isMyPoseSelected: (pose) =>
                        _selectedMyPoses.any((p) => p.name == pose.name),
                    poses: _myPoses,
                    allLocalPoses: _allPoses,
                    loading: _loadingMy,
                    orange: _orange,
                    surface: _surface,
                    textSecondary: _textSecondary,
                    textPrimary: _textPrimary,
                    bg: _bg,
                    border: _divider,
                    onRemove: _removePose,
                    onRefresh: _loadMyPoses,
                    selectedPoses: _selectedPoses,
                    onToggleSelect: _togglePoseSelection,
                    isPoseSelected: _isPoseSelected,
                    onAddPose: _handleAddPose,
                    processingPoses: _processingPoses,
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
              child: Icon(Icons.close_rounded, color: _textPrimary, size: 16),
            ),
          ),
          const Spacer(),
          Text(
            _selectedPoses.isEmpty
                ? 'Select Poses'
                : 'Select Poses (${_selectedPoses.length})',
            style: TextStyle(
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
                child: Text(
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
    final hasSelection =
        _selectedPoses.isNotEmpty || _selectedMyPoses.isNotEmpty;
    final count = _selectedPoses.length + _selectedMyPoses.length;
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
                    : _disabledBg, // ✅ theme-aware
                disabledBackgroundColor: _disabledBg, // ✅ theme-aware
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
                    color: hasSelection
                        ? Colors.white
                        : _disabledText, // ✅ theme-aware
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Take Photos ($count)' : 'Take photos',
                    style: TextStyle(
                      color: hasSelection
                          ? Colors.white
                          : _disabledText, // ✅ theme-aware
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
            style: TextStyle(
              color: _disabledText,
              fontSize: 12,
            ), // ✅ theme-aware (const removed)
          ),
        ],
      ),
    );
  }
}

// ── AI Picks Tab ──
class _AiPicksTab extends StatelessWidget {
  final ScanResult? scanResult;
  final List<LocalPose> allPoses;
  final Color orange, surface, textSecondary;
  final VoidCallback onScanNow;
  final Future<void> Function(PoseModel) onSave;
  final List<LocalPose> selectedPoses;
  final void Function(LocalPose) onToggleSelect;
  final bool Function(LocalPose) isPoseSelected;

  const _AiPicksTab({
    required this.scanResult,
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

  List<LocalPose> get _recommended {
    if (scanResult == ScanResult.fullBody) {
      return allPoses
          .where(
            (p) => p.tags.contains('mirror') || p.tags.contains('full-body'),
          )
          .toList();
    }
    return allPoses.where((p) => p.tags.contains('selfie')).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (scanResult == null) return _buildEmpty();

    final recommended = _recommended;
    if (recommended.isEmpty) return _buildNoMatch();

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

  Widget _buildNoMatch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: textSecondary, size: 40),
            const SizedBox(height: 14),
            const Text(
              'No matching poses yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add more poses to your catalog\nfor this framing',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
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
//
// NEW: floating left/right filter rails.
//   Left rail  -> framing filter: Selfie / Full-body (mirror included)
//                 optional — either one active, or none (toggle).
//   Right rail -> people filter : Solo / Dual (multi-person)
//                 MANDATORY — behaves like a radio button. One of the
//                 two is always active (defaults to 'solo' since all
//                 current poses are solo shots). Tapping the already
//                 active option does nothing; tapping the other one
//                 switches the selection. Neither can be deselected.
//
// Filters are independent of each other (can combine Selfie + Solo).
// This tab is the ONLY place these rails appear — AI Picks & My Poses
// are untouched.
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
  // Left rail — framing filter. Values: null, 'selfie', 'full-body'
  String? _framingFilter;
  // Right rail — people-count filter. Values: 'solo', 'dual'.
  // Mandatory / radio-button style — never null, defaults to 'solo'.
  String _peopleFilter = 'solo';

  List<LocalPose> get _filtered {
    return widget.poses.where((p) {
      final matchesFraming =
          _framingFilter == null ||
          p.tags.contains(_framingFilter) ||
          (_framingFilter == 'full-body' && p.tags.contains('mirror'));
      final matchesPeople = p.tags.contains(_peopleFilter);
      return matchesFraming && matchesPeople;
    }).toList();
  }

  void _toggleFraming(String value) {
    setState(() {
      _framingFilter = _framingFilter == value ? null : value;
    });
  }

  void _togglePeople(String value) {
    // Radio-button behavior: always ends up with exactly one option
    // active. Tapping the currently active one is a no-op.
    setState(() {
      _peopleFilter = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.orange, strokeWidth: 2),
      );
    }

    final filtered = _filtered;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: filtered.isEmpty
                  ? _buildNoMatch()
                  : GridView.builder(
                      // extra left/right padding so cards don't sit under the rails
                      padding: const EdgeInsets.fromLTRB(56, 4, 56, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final pose = filtered[i];
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
        ),

        // ── Left rail: framing filters ──
        Positioned(
          left: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _FilterRail(
              orange: widget.orange,
              children: [
                _RailIcon(
                  icon: Icons.camera_front_rounded,
                  label: 'Selfie',
                  active: _framingFilter == 'selfie',
                  orange: widget.orange,
                  onTap: () => _toggleFraming('selfie'),
                ),
                const SizedBox(height: 14),
                _RailIcon(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Full body',
                  active: _framingFilter == 'full-body',
                  orange: widget.orange,
                  onTap: () => _toggleFraming('full-body'),
                ),
              ],
            ),
          ),
        ),

        // ── Right rail: people-count filters (mandatory, radio-style) ──
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _FilterRail(
              orange: widget.orange,
              children: [
                _RailIcon(
                  icon: Icons.person_rounded,
                  label: 'Solo',
                  active: _peopleFilter == 'solo',
                  orange: widget.orange,
                  onTap: () => _togglePeople('solo'),
                ),
                const SizedBox(height: 14),
                _RailIcon(
                  icon: Icons.people_alt_rounded,
                  label: 'Dual',
                  active: _peopleFilter == 'dual',
                  orange: widget.orange,
                  onTap: () => _togglePeople('dual'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoMatch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: widget.textSecondary,
              size: 40,
            ),
            const SizedBox(height: 14),
            const Text(
              'No poses match this filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tag your poses with selfie / full-body\nand solo / dual to use this filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small pill-shaped container that holds the rail icons (matches the
// floating vertical strip look from the reference screenshot).
class _FilterRail extends StatelessWidget {
  final Color orange;
  final List<Widget> children;

  const _FilterRail({required this.orange, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// Single circular toggle icon used inside a _FilterRail.
class _RailIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color orange;
  final VoidCallback onTap;

  const _RailIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.orange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? orange : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? orange : Colors.white24,
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: active ? orange : Colors.white54,
              fontSize: 9,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── My Poses Tab ──
// (lives in my_poses_tab.dart, imported above)

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
    // FIX: selfie images are tight close-up crops (little transparent
    // margin), while mirror images are full-body shots with lots of
    // empty space top/bottom. With the same BoxFit.contain tile,
    // selfie poses render visually bigger than mirror poses. Adding
    // extra padding to selfie images only visually balances the two.
    final extraPadding = pose.category == 'selfie'
        ? const EdgeInsets.all(18.0)
        : EdgeInsets.zero;

    return GestureDetector(
      onTap: onToggleSelect,
      onLongPress: onLongPress != null ? () => onLongPress!() : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Glow that follows the cutout's actual shape (not a box)
          if (isSelected)
            Padding(
              padding: extraPadding,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    orange.withOpacity(0.9),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(pose.image, fit: BoxFit.contain),
                ),
              ),
            ),

          // Sharp image on top — no box, floats on screen bg
          Padding(
            padding: extraPadding,
            child: Image.asset(
              pose.image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                color: Colors.white38,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
