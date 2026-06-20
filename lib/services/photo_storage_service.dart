import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_photo.dart';

/// Handles saving, listing, favouriting, and deleting photos taken
/// inside the app. Photos are stored in the app's own private documents
/// folder (not the phone's public gallery), inside a "pose_muse_photos"
/// subfolder. Metadata (id, path, takenAt, isFavourite) is stored
/// separately in SharedPreferences as a JSON list, the same pattern
/// already used for favourite poses.
class PhotoStorageService {
  static const _prefsKey = 'saved_photos';

  /// Returns the folder where captured photos live, creating it if needed.
  static Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/pose_muse_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a freshly captured photo (from a temp camera file path) into
  /// app storage, creates its SavedPhoto record, and persists it.
  static Future<SavedPhoto> savePhoto(String tempFilePath) async {
    final dir = await _photosDir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newPath = '${dir.path}/$id.jpg';

    final tempFile = File(tempFilePath);
    await tempFile.copy(newPath);

    final photo = SavedPhoto(id: id, path: newPath, takenAt: DateTime.now());

    final all = await getAllPhotos();
    all.insert(0, photo); // newest first
    await _persist(all);

    return photo;
  }

  /// Returns all saved photos, newest first.
  static Future<List<SavedPhoto>> getAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw
        .map((s) {
          try {
            return SavedPhoto.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedPhoto>()
        .toList();
  }

  /// Returns only favourited photos, newest first.
  static Future<List<SavedPhoto>> getFavouritePhotos() async {
    final all = await getAllPhotos();
    return all.where((p) => p.isFavourite).toList();
  }

  /// Toggles the favourite flag on a photo and persists the change.
  static Future<void> toggleFavourite(String id) async {
    final all = await getAllPhotos();
    final idx = all.indexWhere((p) => p.id == id);
    if (idx != -1) {
      all[idx].isFavourite = !all[idx].isFavourite;
      await _persist(all);
    }
  }

  /// Deletes a photo from disk and removes its record.
  static Future<void> deletePhoto(String id) async {
    final all = await getAllPhotos();
    final idx = all.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final file = File(all[idx].path);
      if (await file.exists()) {
        await file.delete();
      }
      all.removeAt(idx);
      await _persist(all);
    }
  }

  static Future<void> _persist(List<SavedPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = photos.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_prefsKey, encoded);
  }
}
