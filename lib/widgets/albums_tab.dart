import 'dart:io';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:uuid/uuid.dart';
import '../models/album_model.dart';
import '../models/pose_model.dart';

class AlbumsTab extends StatelessWidget {
  final List<PoseModel> allPoses;
  final Color accent;
  final Color surface;
  final Color bg;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  const AlbumsTab({
    required this.allPoses,
    required this.accent,
    required this.surface,
    required this.bg,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Album>>(
      stream: FirestoreService.albumsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: accent));
        }
        final albums = snap.data ?? [];

        if (albums.isEmpty) {
          return _EmptyAlbums(
            accent: accent,
            surface: surface,
            border: border,
            textPrimary: textPrimary,
            onTap: () => _startCreate(context),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            childAspectRatio: 0.95,
          ),
          itemCount: albums.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return _NewAlbumTile(
                accent: accent,
                surface: surface,
                onTap: () => _startCreate(context),
              );
            }
            final album = albums[i - 1];
            return _AlbumCard(
              album: album,
              accent: accent,
              surface: surface,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              allPoses: allPoses,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(
                    album: album,
                    allPoses: allPoses,
                    accent: accent,
                    surface: surface,
                    bg: bg,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    border: border,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PoseSelectSheet(
        allPoses: allPoses,
        accent: accent,
        surface: surface,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        border: border,
      ),
    );
  }
}

// ── Empty state ──
class _EmptyAlbums extends StatelessWidget {
  final Color accent, surface, border, textPrimary;
  final VoidCallback onTap;
  const _EmptyAlbums({
    required this.accent,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Icon(Icons.folder_outlined, color: accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'No albums yet',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Group your poses into albums',
            style: TextStyle(color: accent.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Create album',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── New album dashed tile ──
class _NewAlbumTile extends StatelessWidget {
  final Color accent, surface;
  final VoidCallback onTap;
  const _NewAlbumTile({
    required this.accent,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashedRectPainter(color: accent),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: accent, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        'New album',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Album card with 4-photo mosaic ──
class _AlbumCard extends StatelessWidget {
  final Album album;
  final Color accent, surface, textPrimary, textSecondary;
  final List<PoseModel> allPoses;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.allPoses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final paths = album.poseImagePaths.take(4).toList();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: paths.isEmpty
                  ? Container(
                      color: surface,
                      child: Icon(
                        Icons.folder_outlined,
                        color: textSecondary,
                        size: 28,
                      ),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: List.generate(4, (i) {
                        if (i < paths.length) {
                          return _thumb(paths[i]);
                        }
                        return Container(color: surface);
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${album.poseImagePaths.length} poses',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String path) {
    if (path.startsWith('/')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: surface),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: surface),
    );
  }
}

// ── Step 1: Pose selection bottom sheet ──
class _PoseSelectSheet extends StatefulWidget {
  final List<PoseModel> allPoses;
  final Color accent, surface, textPrimary, textSecondary, border;
  const _PoseSelectSheet({
    required this.allPoses,
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  @override
  State<_PoseSelectSheet> createState() => _PoseSelectSheetState();
}

class _PoseSelectSheetState extends State<_PoseSelectSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: widget.textPrimary,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Select poses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(
                      color: widget.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Grid
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: widget.allPoses.length,
                itemBuilder: (_, i) {
                  final pose = widget.allPoses[i];
                  final key = pose.imagePath ?? '';
                  final sel = _selected.contains(key);
                  return GestureDetector(
                    onTap: () => setState(() {
                      sel ? _selected.remove(key) : _selected.add(key);
                    }),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _poseThumb(pose.imagePath),
                        ),
                        if (sel)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: widget.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        if (!sel)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white38, width: 1.5),
                                ),
                                shape: BoxShape.circle,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: widget.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: widget.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selected.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _showNameSheet(context);
                            },
                      child: AnimatedOpacity(
                        opacity: _selected.isEmpty ? 0.45 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: widget.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  void _showNameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NameAlbumSheet(
        accent: widget.accent,
        surface: widget.surface,
        textPrimary: widget.textPrimary,
        textSecondary: widget.textSecondary,
        border: widget.border,
        selectedPaths: _selected.toList(),
      ),
    );
  }

  Widget _poseThumb(String? path) {
    if (path == null || path.isEmpty) return Container(color: widget.surface);
    if (path.startsWith('/')) return Image.file(File(path), fit: BoxFit.cover);
    return Image.asset(path, fit: BoxFit.cover);
  }
}

// ── Step 2: Name album bottom sheet ──
class _NameAlbumSheet extends StatefulWidget {
  final Color accent, surface, textPrimary, textSecondary, border;
  final List<String> selectedPaths;
  const _NameAlbumSheet({
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.selectedPaths,
  });

  @override
  State<_NameAlbumSheet> createState() => _NameAlbumSheetState();
}

class _NameAlbumSheetState extends State<_NameAlbumSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final album = Album(
      id: const Uuid().v4(),
      name: name,
      poseImagePaths: widget.selectedPaths,
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveAlbum(album);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Album name',
              style: TextStyle(
                color: widget.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: widget.textPrimary, fontSize: 14),
              cursorColor: widget.accent,
              decoration: InputDecoration(
                hintText: 'e.g. Summer shoot',
                hintStyle: TextStyle(color: widget.textSecondary, fontSize: 14),
                filled: true,
                fillColor: widget.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.border),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: widget.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
    );
  }
}

// ── Album detail screen ──
class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  final List<PoseModel> allPoses;
  final Color accent, surface, bg, textPrimary, textSecondary, border;

  const AlbumDetailScreen({
    required this.album,
    required this.allPoses,
    required this.accent,
    required this.surface,
    required this.bg,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _renaming = false;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.album.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRename() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.album.name = name;
    await FirestoreService.updateAlbum(widget.album);
    setState(() => _renaming = false);
  }

  Future<void> _deleteAlbum() async {
    await FirestoreService.deleteAlbum(widget.album.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.bg,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: widget.textPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _renaming
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: widget.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  cursorColor: widget.accent,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: widget.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: widget.accent,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: widget.accent,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: widget.accent,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _saveRename(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _saveRename,
                                child: Icon(
                                  Icons.check_rounded,
                                  color: widget.accent,
                                  size: 22,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.album.name,
                                  style: TextStyle(
                                    color: widget.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(() => _renaming = true),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: widget.textSecondary,
                                  size: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Delete option
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: widget.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.album.poseImagePaths.length} poses',
                  style: TextStyle(color: widget.textSecondary, fontSize: 11),
                ),
              ),
            ),
            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: widget.album.poseImagePaths.length + 1,
                itemBuilder: (_, i) {
                  // Last tile = "Add more"
                  if (i == 0) {
                    return GestureDetector(
                      onTap: () => _addMore(context),
                      child: CustomPaint(
                        painter: _DashedRectPainter(color: widget.accent),
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: widget.accent,
                                  size: 18,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add more',
                                  style: TextStyle(
                                    color: widget.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final path = widget.album.poseImagePaths[i - 1];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _thumb(path),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String path) {
    if (path.startsWith('/'))
      return Image.file(File(path), fit: BoxFit.cover); // contain → cover
    return Image.asset(path, fit: BoxFit.cover);
  }

  void _addMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMoreSheet(
        album: widget.album,
        allPoses: widget.allPoses,
        accent: widget.accent,
        surface: widget.surface,
        textPrimary: widget.textPrimary,
        border: widget.border,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final del = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: widget.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete album?',
          style: TextStyle(color: widget.textPrimary, fontSize: 15),
        ),
        content: Text(
          'This will remove the album but not your poses.',
          style: TextStyle(color: widget.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: widget.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: widget.accent)),
          ),
        ],
      ),
    );
    if (del == true) _deleteAlbum();
  }
}

// ── Add more poses to existing album ──
class _AddMoreSheet extends StatefulWidget {
  final Album album;
  final List<PoseModel> allPoses;
  final Color accent, surface, textPrimary, border;
  const _AddMoreSheet({
    required this.album,
    required this.allPoses,
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.border,
  });

  @override
  State<_AddMoreSheet> createState() => _AddMoreSheetState();
}

class _AddMoreSheetState extends State<_AddMoreSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.album.poseImagePaths.toSet();
  }

  Future<void> _save() async {
    widget.album.poseImagePaths = _selected.toList();
    await FirestoreService.updateAlbum(widget.album);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: widget.textPrimary,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add poses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: widget.allPoses.length,
                itemBuilder: (_, i) {
                  final pose = widget.allPoses[i];
                  final key = pose.imagePath ?? '';
                  final sel = _selected.contains(key);
                  return GestureDetector(
                    onTap: () => setState(
                      () => sel ? _selected.remove(key) : _selected.add(key),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: key.startsWith('/')
                              ? Image.file(File(key), fit: BoxFit.cover)
                              : Image.asset(key, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: sel ? widget.accent : Colors.black38,
                              shape: BoxShape.circle,
                              border: sel
                                  ? null
                                  : Border.all(
                                      color: Colors.white38,
                                      width: 1.5,
                                    ),
                            ),
                            child: sel
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed border painter ──
class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(14),
        ),
      );
    const dash = 5.0, gap = 4.0;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
