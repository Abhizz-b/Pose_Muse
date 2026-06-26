import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/album_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference get _albums =>
      _db.collection('users').doc(_uid).collection('albums');

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
}
