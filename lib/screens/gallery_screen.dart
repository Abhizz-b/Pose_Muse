import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_photo.dart';
import '../services/photo_storage_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _orange = Color(0xFF9C6FFF);
  static const Color _divider = Color(0xFF2A2A2A);

  static const int _crossAxisCount = 3;
  static const double _gridSpacing = 6;
  static const double _gridPadding = 12;
  static const double _itemAspectRatio = 0.8;

  List<SavedPhoto> _photos = [];
  bool _loading = true;
  bool _showFavouritesOnly = false;

  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  // Drag-to-select tracking
  final GlobalKey _gridKey = GlobalKey();
  int? _dragAnchorIndex; // index where the drag started
  int? _lastDragIndex; // last index the drag touched
  bool _dragModeIsSelecting =
      true; // whether this drag is selecting or deselecting

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

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
        ),
      ),
    );
    _loadPhotos();
  }

  // firstId is optional: pass it when entering via long-press or drag on a
  // photo (that photo gets selected immediately). Leave null when entering
  // via the "Select" button (nothing selected yet).
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
      // NOTE: we no longer auto-exit select mode when selection hits zero.
      // The user must tap "Cancel" to leave select mode, so the footer
      // can show the disabled "Select items" state.
    });
  }

  // ── Drag-to-select logic ──

  int? _indexAtGlobalPosition(Offset globalPosition) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);

    // Account for grid padding
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

    // Make sure the point actually landed inside the cell, not in the
    // spacing gap between cells.
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

    // If we're not in select mode yet, this drag starts it.
    if (!_selectMode) {
      _enterSelectMode();
    }

    // Decide whether this whole drag gesture will select or deselect,
    // based on the state of the very first photo touched.
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
    if (files.isNotEmpty) {
      await Share.shareXFiles(files);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Delete photos?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete $count photo${count == 1 ? '' : 's'}.',
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
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _orange,
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
                border: Border.all(color: _divider),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'My Photos',
            style: TextStyle(
              color: Colors.white,
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
                  border: Border.all(color: _divider),
                ),
                child: Text(
                  _selectMode ? 'Cancel' : 'Select',
                  style: const TextStyle(
                    color: Colors.white,
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
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white60,
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
            color: Colors.white38,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            _showFavouritesOnly ? 'No favourites yet' : 'No photos yet',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _showFavouritesOnly
                ? 'Bestie, double-tap your iconic shots to save them here <3 '
                : 'Bestie, snap your first iconic shot ',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GestureDetector(
      // Using pan instead of long-press-drag so a deliberate drag works
      // even when not already in select mode. Single taps still pass
      // through to each item's own GestureDetector.
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
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  if (!_selectMode && photo.isFavourite)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: _orange,
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
                              ? _orange
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
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _footerIcon(
            icon: Icons.share_rounded,
            enabled: hasSelection,
            onTap: hasSelection ? _shareSelected : null,
          ),
          Text(
            hasSelection
                ? '$count item${count == 1 ? '' : 's'} selected'
                : 'Select items',
            style: TextStyle(
              color: hasSelection ? Colors.white : Colors.white38,
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
      child: Icon(icon, color: enabled ? color : Colors.white24, size: 24),
    );
  }
}

// ── Full-screen photo viewer with left-right swipe ──
class _PhotoViewerScreen extends StatefulWidget {
  final List<SavedPhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  static const Color _orange = Color(0xFF9C6FFF);
  late PageController _pageController;
  late List<SavedPhoto> _photos;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavourite() async {
    HapticFeedback.lightImpact();
    final photo = _photos[_currentIndex];
    await PhotoStorageService.toggleFavourite(photo.id);
    setState(() => photo.isFavourite = !photo.isFavourite);
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
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Delete photo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This photo will be permanently deleted.',
          style: TextStyle(color: Colors.white54),
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
      return const Scaffold(backgroundColor: Colors.black, body: SizedBox());
    }
    final currentPhoto = _photos[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
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
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
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
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onDoubleTap: _toggleFavourite,
                    child: InteractiveViewer(
                      child: Image.file(
                        File(_photos[i].path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
                    color: currentPhoto.isFavourite ? _orange : Colors.white,
                    onTap: _toggleFavourite,
                  ),
                  _actionButton(
                    icon: Icons.share_rounded,
                    color: Colors.white,
                    onTap: _sharePhoto,
                  ),
                  _actionButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.white,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
