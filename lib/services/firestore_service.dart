import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/album_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference get _albums =>
      _db.collection('users').doc(_uid).collection('albums');

  static DocumentReference get _userDoc =>
      _db.collection('users').doc(_uid);

  // ── Albums ──

  static Stream<List<Album>> albumsStream() {
    return _albums
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Album.fromFirestore(d)).toList());
  }

  static Future<void> saveAlbum(Album album) async {
    await _albums.doc(album.id).set(album.toFirestore());
  }

  static Future<void> updateAlbum(Album album) async {
    await _albums.doc(album.id).update(album.toFirestore());
  }

  static Future<void> deleteAlbum(String albumId) async {
    await _albums.doc(albumId).delete();
  }

  // ── User Preferences ──

  /// Save notification preferences to Firestore
  static Future<void> saveNotificationPrefs({
    required bool pushNotifications,
    required bool poseReminders,
  }) async {
    await _userDoc.set({
      'prefs': {
        'pushNotifications': pushNotifications,
        'poseReminders': poseReminders,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Load notification preferences from Firestore
  /// Returns map with keys: pushNotifications (bool), poseReminders (bool)
  static Future<Map<String, bool>> loadNotificationPrefs() async {
    try {
      final doc = await _userDoc.get();
      if (!doc.exists) return {'pushNotifications': true, 'poseReminders': true};
      final data = doc.data() as Map<String, dynamic>?;
      final prefs = data?['prefs'] as Map<String, dynamic>?;
      return {
        'pushNotifications': prefs?['pushNotifications'] as bool? ?? true,
        'poseReminders': prefs?['poseReminders'] as bool? ?? true,
      };
    } catch (_) {
      return {'pushNotifications': true, 'poseReminders': true};
    }
  }

  /// Save theme preference to Firestore
  static Future<void> saveThemePref(int themeIndex) async {
    await _userDoc.set({
      'prefs': {'themeIndex': themeIndex},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Load theme preference (0=System, 1=Light, 2=Dark)
  static Future<int> loadThemePref() async {
    try {
      final doc = await _userDoc.get();
      if (!doc.exists) return 2;
      final data = doc.data() as Map<String, dynamic>?;
      final prefs = data?['prefs'] as Map<String, dynamic>?;
      return prefs?['themeIndex'] as int? ?? 2;
    } catch (_) {
      return 2;
    }
  }

  // ── Profile Photo (base64 — Firebase Storage ke bina) ──

  /// Save base64-encoded profile photo to Firestore
  static Future<void> saveProfilePhoto(String base64Image) async {
    await _userDoc.set({
      'profilePhotoBase64': base64Image,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Load base64 profile photo string (null if not set)
  static Future<String?> loadProfilePhoto() async {
    try {
      final doc = await _userDoc.get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      return data?['profilePhotoBase64'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Delete profile photo from Firestore
  static Future<void> deleteProfilePhoto() async {
    await _userDoc.update({'profilePhotoBase64': FieldValue.delete()});
  }
}
