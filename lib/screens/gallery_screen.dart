import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_photo.dart';
import '../services/photo_storage_service.dart';
import 'settings_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color _purple = Color(0xFF9C6FFF);

  // Theme-aware
  static const _bgDark = Color(0xFF0D0D0D);
  static const _bgLight = Color(0xFFF5F5F7);
  static const _surfaceDark = Color(0xFF1A1A1A);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _borderDark = Color(0xFF2A2A2A);
  static const _borderLight = Color(0xFFE0E0E0);

  static const int _crossAxisCount = 3;
  static const double _gridSpacing = 6;
  static const double _gridPadding = 12;
  static const double _itemAspectRatio = 0.8;

  List<SavedPhoto> _photos = [];
  bool _loading = true;
  bool _showFavouritesOnly = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  final GlobalKey _gridKey = GlobalKey();
  int? _dragAnchorIndex;
  int? _lastDragIndex;
  bool _dragModeIsSelecting = true;

  bool get _isDark => themeNotifier.value != ThemeMode.light;
  Color get _bg => _isDark ? _bgDark : _bgLight;
  Color get _surface => _isDark ? _surfaceDark : _surfaceLight;
  Color get _border => _isDark ? _borderDark : _borderLight;
  Color get _textPrimary =>
      _isDark ? const Color(0xFFF3F3F3) : const Color(0xFF111111);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF888888) : const Color(0xFF666666);
  Color get _textWhite => _isDark ? Colors.white : const Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _loadPhotos();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    final photos = _showFavouritesOnly
        ? await PhotoStorageService.getFavouritePhotos()
        : await PhotoStorageService.getAllPhotos();
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  Future<void> _openPhoto(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          photos: _photos,
          initialIndex: index,
          onChanged: _loadPhotos,
          isDark: _isDark,
        ),
      ),
    );
    _loadPhotos();
  }

  void _enterSelectMode([String? firstId]) {
    setState(() {
      _selectMode = true;
      _selectedIds.clear();
      if (firstId != null) _selectedIds.add(firstId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  int? _indexAtGlobalPosition(Offset globalPosition) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    final x = local.dx - _gridPadding;
    final y = local.dy - _gridPadding;
    if (x < 0 || y < 0) return null;
    final totalWidth = box.size.width - (_gridPadding * 2);
    final cellWidth =
        (totalWidth - (_gridSpacing * (_crossAxisCount - 1))) / _crossAxisCount;
    final cellHeight = cellWidth / _itemAspectRatio;
    final col = (x / (cellWidth + _gridSpacing)).floor();
    final row = (y / (cellHeight + _gridSpacing)).floor();
    if (col < 0 || col >= _crossAxisCount || row < 0) return null;
    final index = row * _crossAxisCount + col;
    if (index < 0 || index >= _photos.length) return null;
    final cellLocalX = x - col * (cellWidth + _gridSpacing);
    final cellLocalY = y - row * (cellHeight + _gridSpacing);
    if (cellLocalX > cellWidth || cellLocalY > cellHeight) return null;
    return index;
  }

  void _handleDragStart(DragStartDetails details) {
    final index = _indexAtGlobalPosition(details.globalPosition);
    if (index == null) return;
    final photo = _photos[index];
    final alreadySelected = _selectedIds.contains(photo.id);
    if (!_selectMode) _enterSelectMode();
    _dragModeIsSelecting = !alreadySelected;
    _dragAnchorIndex = index;
    _lastDragIndex = index;
    setState(() {
      if (_dragModeIsSelecting) {
        _selectedIds.add(photo.id);
      } else {
        _selectedIds.remove(photo.id);
      }
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_selectMode) return;
    final index = _indexAtGlobalPosition(details.globalPosition);
    if (index == null || index == _lastDragIndex) return;
    _lastDragIndex = index;
    final photo = _photos[index];
    setState(() {
      if (_dragModeIsSelecting) {
        _selectedIds.add(photo.id);
      } else {
        _selectedIds.remove(photo.id);
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragAnchorIndex = null;
    _lastDragIndex = null;
  }

  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    final files = _photos
        .where((p) => _selectedIds.contains(p.id))
        .map((p) => XFile(p.path))
        .toList();
    if (files.isNotEmpty) await Share.shareXFiles(files);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Delete photos?', style: TextStyle(color: _textPrimary)),
        content: Text(
          'This will permanently delete $count photo${count == 1 ? '' : 's'}.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE24B4A)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selectedIds) {
        await PhotoStorageService.deletePhoto(id);
      }
      _exitSelectMode();
      _loadPhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _purple,
                        strokeWidth: 2,
                      ),
                    )
                  : _photos.isEmpty
                  ? _buildEmpty()
                  : _buildGrid(),
            ),
            if (_selectMode) _buildSelectFooter(),
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
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.close_rounded, color: _textPrimary, size: 16),
            ),
          ),
          const Spacer(),
          Text(
            'My Photos',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_photos.isNotEmpty)
            GestureDetector(
              onTap: () {
                if (_selectMode) {
                  _exitSelectMode();
                } else {
                  _enterSelectMode();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  _selectMode ? 'Cancel' : 'Select',
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

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 42,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _filterTab('All', !_showFavouritesOnly),
          _filterTab('Favourites', _showFavouritesOnly),
        ],
      ),
    );
  }

  Widget _filterTab(String label, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _showFavouritesOnly = label == 'Favourites');
          _exitSelectMode();
          _loadPhotos();
        },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? (_isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? (_isDark ? Colors.black : Colors.white)
                    : _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showFavouritesOnly
                ? Icons.favorite_border_rounded
                : Icons.photo_outlined,
            color: _textSecondary,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            _showFavouritesOnly ? 'No favourites yet' : 'No photos yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _showFavouritesOnly
                ? 'Bestie, double-tap your iconic shots to save them here'
                : 'Bestie, snap your first iconic shot',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GestureDetector(
      onPanStart: _handleDragStart,
      onPanUpdate: _handleDragUpdate,
      onPanEnd: _handleDragEnd,
      child: GridView.builder(
        key: _gridKey,
        padding: const EdgeInsets.all(_gridPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _crossAxisCount,
          crossAxisSpacing: _gridSpacing,
          mainAxisSpacing: _gridSpacing,
          childAspectRatio: _itemAspectRatio,
        ),
        itemCount: _photos.length,
        itemBuilder: (_, i) {
          final photo = _photos[i];
          final isSelected = _selectedIds.contains(photo.id);
          return GestureDetector(
            onTap: () {
              if (_selectMode) {
                _toggleSelected(photo.id);
              } else {
                _openPhoto(i);
              }
            },
            onLongPress: () {
              if (!_selectMode) {
                HapticFeedback.mediumImpact();
                _enterSelectMode(photo.id);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _surface,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  if (!_selectMode && photo.isFavourite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: _purple,
                        size: 16,
                      ),
                    ),
                  if (_selectMode)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        color: isSelected
                            ? Colors.black.withOpacity(0.35)
                            : Colors.transparent,
                      ),
                    ),
                  if (_selectMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _purple
                              : Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              isSelected ? 0 : 0.8,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectFooter() {
    final count = _selectedIds.length;
    final hasSelection = count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _footerIcon(
            icon: Icons.share_rounded,
            enabled: hasSelection,
            color: _textPrimary,
            onTap: hasSelection ? _shareSelected : null,
          ),
          Text(
            hasSelection
                ? '$count item${count == 1 ? '' : 's'} selected'
                : 'Select items',
            style: TextStyle(
              color: hasSelection ? _textPrimary : _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          _footerIcon(
            icon: Icons.delete_outline_rounded,
            enabled: hasSelection,
            color: const Color(0xFFE24B4A),
            onTap: hasSelection ? _deleteSelected : null,
          ),
        ],
      ),
    );
  }

  Widget _footerIcon({
    required IconData icon,
    required bool enabled,
    VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: enabled ? color : _textSecondary.withOpacity(0.4),
        size: 24,
      ),
    );
  }
}

// Photo viewer — now theme-aware (was hardcoded dark before)
class _PhotoViewerScreen extends StatefulWidget {
  final List<SavedPhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;
  final bool isDark;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _purple = Color(0xFF9C6FFF);
  late PageController _pageController;
  late List<SavedPhoto> _photos;
  late int _currentIndex;
  late AnimationController _heartBounceController;
  late Animation<double> _heartScale;

  // Theme-aware colors (driven by widget.isDark, passed in from GalleryScreen)
  bool get _isDark => widget.isDark;
  Color get _bg => _isDark ? Colors.black : const Color(0xFFF5F5F7);
  Color get _surface => _isDark ? const Color(0xFF1C1C1C) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF111111);
  Color get _textSecondary =>
      _isDark ? Colors.white54 : const Color(0xFF666666);
  Color get _iconColor => _isDark ? Colors.white : const Color(0xFF111111);
  Color get _circleBg =>
      _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06);
  Color get _actionBtnBg =>
      _isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _heartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_heartBounceController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartBounceController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavourite() async {
    HapticFeedback.lightImpact();
    final photo = _photos[_currentIndex];
    await PhotoStorageService.toggleFavourite(photo.id);
    setState(() => photo.isFavourite = !photo.isFavourite);
    _heartBounceController.forward(from: 0);
    widget.onChanged();
  }

  Future<void> _sharePhoto() async {
    HapticFeedback.lightImpact();
    final photo = _photos[_currentIndex];
    await Share.shareXFiles([XFile(photo.path)]);
  }

  Future<void> _deletePhoto() async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Delete photo?', style: TextStyle(color: _textPrimary)),
        content: Text(
          'This photo will be permanently deleted.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE24B4A)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final photo = _photos[_currentIndex];
      await PhotoStorageService.deletePhoto(photo.id);
      widget.onChanged();
      if (!mounted) return;
      setState(() {
        _photos.removeAt(_currentIndex);
        if (_photos.isEmpty) {
          Navigator.pop(context);
        } else if (_currentIndex >= _photos.length) {
          _currentIndex = _photos.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return Scaffold(backgroundColor: _bg, body: const SizedBox());
    }
    final currentPhoto = _photos[_currentIndex];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _circleBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: _iconColor,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => GestureDetector(
                  onDoubleTap: _toggleFavourite,
                  child: InteractiveViewer(
                    child: Image.file(
                      File(_photos[i].path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _textSecondary,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _actionButton(
                    icon: currentPhoto.isFavourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: currentPhoto.isFavourite ? _purple : _iconColor,
                    onTap: _toggleFavourite,
                    scale: _heartScale,
                  ),
                  _actionButton(
                    icon: Icons.share_rounded,
                    color: _iconColor,
                    onTap: _sharePhoto,
                  ),
                  _actionButton(
                    icon: Icons.delete_outline_rounded,
                    color: _iconColor,
                    onTap: _deletePhoto,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Animation<double>? scale,
  }) {
    final iconWidget = Icon(icon, color: color, size: 24);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: _actionBtnBg, shape: BoxShape.circle),
        child: scale != null
            ? ScaleTransition(scale: scale, child: iconWidget)
            : iconWidget,
      ),
    );
  }
}
